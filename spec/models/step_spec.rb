require 'rails_helper'

def assert_equal(a,b)
  expect(a).to eq(b)
end

def cwm_engine?
  Rails.configuration.inference_engine == :cwm
end

RSpec.describe Step, type: :model do

  def build_instance
    create_step
  end


  Struct.new('FakeFact', :predicate, :object)

  def create_step
    FactoryGirl.create(:step, {
      :step_type =>@step_type,
      :asset_group => @asset_group
    })
  end


  describe '#execute_actions' do
    setup do
      @step_type = FactoryGirl.create :step_type

      @cg1 = FactoryGirl.create(:condition_group,{:name => 'p'})
      @cg1.conditions << FactoryGirl.create(:condition,{
        :predicate => 'is', :object => 'Tube'})
      @cg2 = FactoryGirl.create(:condition_group,{:name => 'q'})
      @cg2.conditions << FactoryGirl.create(:condition,{
        :predicate => 'is', :object => 'Rack'})
      @step_type.condition_groups << @cg1
      @step_type.condition_groups << @cg2
      @tubes = 7.times.map{|i| FactoryGirl.create(:asset, {:facts =>[
        FactoryGirl.create(:fact, :predicate => 'is', :object => 'Tube'),
        FactoryGirl.create(:fact, :predicate => 'is', :object => 'Full')
        ]})}
      @racks = 5.times.map{|i| FactoryGirl.create(:asset, {:facts =>[
        FactoryGirl.create(:fact, :predicate => 'is', :object => 'Rack'),
        FactoryGirl.create(:fact, :predicate => 'is', :object => 'Full')
        ]})}
      @assets = [@tubes, @racks].flatten
      @asset_group = FactoryGirl.create(:asset_group, {:assets => @assets})
    end

    describe 'when creating a new step' do
      it 'raises an exception if assets are not compatible with step_type' do
        @cg1.update_attributes(:cardinality => 1)
        expect{
          @step = create_step
          }.to raise_error(StandardError)
      end
    end

    describe 'with related assets in conditions' do
      setup do
        @cg2.conditions << FactoryGirl.create(:condition, {
          :predicate => 'contains', :object_condition_group_id => @cg1.id})

        @action = FactoryGirl.create(:action, {:action_type => 'addFacts',
          :predicate => 'is', :object => 'TubeRack', :subject_condition_group => @cg2})
        @step_type.actions << @action

        @racks.each_with_index do |r, i|
          r.facts << FactoryGirl.create(:fact, :predicate => 'contains', :object_asset_id => @tubes[i].id)
        end
      end

      it 'executes the step when the related condition is met' do
        previous_num = @asset_group.assets.count
        @step = create_step

        @racks.each(&:reload)

        @racks.each do |rack|
          assert_equal true, rack.has_fact?(@action)
        end
        expect(Operation.all.count).to eq(@racks.count)
      end

      describe 'with wildcards' do
        setup do
          @wildcard = FactoryGirl.create :condition_group
          condition = FactoryGirl.create :condition, {:predicate => 'position',
            :object_condition_group => @wildcard}
          @cg2.conditions << condition
        end

        describe 'when the conditions is not met' do
          it 'does not execute the rule when the wildcard condition is not met' do
            previous_num = @asset_group.assets.count

            expect{
              @step = create_step
            }.to raise_error(StandardError)

            @racks.each(&:reload)

            @racks.each do |rack|
              assert_equal false, rack.has_fact?(@action)
            end
            expect(Operation.all.count).to eq(0)
          end

        end

        describe 'when the wildcard conditions are met' do
          setup do
            @racks.each_with_index do |rack, idx|
              rack.facts << FactoryGirl.create(:fact, {
                :predicate => 'position',
                :object => idx.to_s
              })
            end
          end

          it 'executes wildcard condition groups' do
            previous_num = @asset_group.assets.count

            @step = create_step

            @racks.each(&:reload)

            @racks.each do |rack|
              assert_equal true, rack.has_fact?(@action)
            end
            expect(Operation.all.count).to eq(@racks.count)
          end

          it 'uses the value of the condition group evaluated for the same cg' do
            previous_num = @asset_group.assets.count

            @action = FactoryGirl.create(:action, {:action_type => 'addFacts',
              :predicate => 'value', :object_condition_group => @wildcard,
              :subject_condition_group => @cg2
            })
            @step_type.actions << @action

            @step = create_step

            @racks.each(&:reload)

            @racks.each_with_index do |rack, pos|
              assert_equal true, rack.has_literal?('value', pos.to_s)
            end
            expect(Operation.all.count).to eq(2*@racks.count)
          end

          it 'uses the value of the condition group to relate different groups' do
            # ?x :t ?pos . ?y :v ?pos . => ?x :relates ?y .
            

            previous_num = @asset_group.assets.count
            @cg1.conditions << FactoryGirl.create(:condition, {:predicate => 'location',
            :object_condition_group => @wildcard})
            @cg2.conditions << FactoryGirl.create(:condition, {:predicate => 'location',
            :object_condition_group => @wildcard})
            @action = FactoryGirl.create(:action, {:action_type => 'addFacts',
              :predicate => 'relates', :object_condition_group => @cg1,
              :subject_condition_group => @cg2
            })
            @step_type.actions << @action

            @tubes.each_with_index do |tube, idx|
              tube.facts << FactoryGirl.create(:fact, {
                :predicate => 'location',
                :object => idx.to_s
              })
            end

            @racks.each_with_index do |rack, idx|
              rack.facts << FactoryGirl.create(:fact, {
                :predicate => 'location',
                :object => idx.to_s
              })
            end

            @step = create_step

            @racks.each(&:reload)
            @tubes.each(&:reload)

            @tubes.each_with_index do |tube, pos|
              assert_equal true, tube.facts.with_predicate('relates').count==0
            end
            @racks.each_with_index do |rack, pos|
              assert_equal true, rack.facts.with_predicate('relates').count!=0
            end
            @racks.zip(@tubes).each do |list|
              rack,tube = list[0],list[1]
              assert_equal tube, rack.facts.with_predicate('relates').first.object_asset
            end

          end

        end
      end
    end

    describe 'with createAsset action type' do
      setup do
        @cg3 = FactoryGirl.create(:condition_group, {:name => 'r'})
        @cg3.conditions << FactoryGirl.create(:condition, {
          :predicate => 'is', :object => 'NewTube'
        })
        @action = FactoryGirl.create(:action, {:action_type => 'createAsset',
          :predicate => 'is', :object => 'NewTube', :subject_condition_group => @cg3})
        if cwm_engine?
          @action2 = FactoryGirl.create(:action, {:action_type => 'createAsset',
            :predicate => 'createdBy', :object_condition_group => @cg1, :subject_condition_group => @cg3})
          @action3 = FactoryGirl.create(:action, {:action_type => 'createAsset',
            :predicate => 'createdBy', :object_condition_group => @cg2, :subject_condition_group => @cg3})

          @step_type.actions << [@action, @action2, @action3]
        else
          @step_type.actions << @action
        end
      end

      it 'creates an asset for each input and adds it to the asset group' do
        previous_num = @asset_group.assets.count
        @step = create_step

        @asset_group.reload
        assets_created = Asset.with_fact('is', 'NewTube')
        expect(previous_num).not_to eq(@asset_group.assets.count)
        #expect(assets_created.length).to eq(previous_num)
        if cwm_engine?
          expect(assets_created.length).to eq(@tubes.count * @racks.count)
          expect(Operation.all.count).to eq(assets_created.count*3)
        else
          expect(assets_created.length).to eq(previous_num)
          expect(Operation.all.count).to eq(assets_created.count)
        end
        expect(assets_created.length+previous_num).to eq(@asset_group.assets.count)
      end

      unless cwm_engine?
        it 'cardinality restricts the number of assets created when it is below the number of inputs' do
          previous_num = @asset_group.assets.count
          @cg3.update_attributes(:cardinality => 6)
          @step = create_step

          @asset_group.reload
          assets_created = Asset.with_fact('is', 'NewTube')
          expect(previous_num).not_to eq(@asset_group.assets.count)
          expect(assets_created.length).to eq(6)
          expect(assets_created.length+previous_num).to eq(@asset_group.assets.count)

          expect(Operation.all.count).to eq(assets_created.count)
        end

        it 'cardinality does not restrict the number of assets created when it is over the number of inputs' do
          previous_num = @asset_group.assets.count
          @cg3.update_attributes(:cardinality => @tubes.length + @racks.length + 2)
          @step = create_step

          @asset_group.reload
          assets_created = Asset.with_fact('is', 'NewTube')
          expect(previous_num).not_to eq(@asset_group.assets.count)
          expect(assets_created.length).to eq(previous_num)
          expect(assets_created.length+previous_num).to eq(@asset_group.assets.count)

          expect(Operation.all.count).to eq(assets_created.count)
        end
      end

      it 'adds facts to all the assets created' do
        previous_num = @asset_group.assets.count
        action = FactoryGirl.create(:action, { :action_type => 'createAsset',
          :predicate => 'has', :object => "MoreData", :subject_condition_group => @cg3})
        @step_type.actions << action

        @step = create_step
        @asset_group.reload
        assets_created = Asset.with_fact('has', 'MoreData')
        assets2_created = Asset.with_fact('is', 'NewTube')
        expect(assets_created - assets2_created).to eq([])
        expect(assets2_created - assets_created).to eq([])
        expect(previous_num).not_to eq(@asset_group.assets.count)
        if cwm_engine?
          expect(assets_created.length).to eq(@tubes.count * @racks.count)
          expect(Operation.all.count).to eq(4*assets_created.count)
        else
          expect(assets_created.length).to eq(previous_num)
          expect(Operation.all.count).to eq(2*assets_created.count)
        end        
        expect(assets_created.length+previous_num).to eq(@asset_group.assets.count)
      end

      it 'throws exception in any attempt to modify the facts of the created asset' do
        previous_num = @asset_group.assets.count
        action = FactoryGirl.create(:action, {:action_type => 'addFacts',
          :predicate => 'has', :object => 'MoreData', :subject_condition_group => @cg3})
        @step_type.actions << action
        expect{
          @step = create_step
          }.to raise_exception Step::UnknownConditionGroup
        expect(Operation.all.count).to eq(0)
      end

      describe 'with overlapping assets' do
        setup do
          @tubes_and_racks = 7.times.map do
            FactoryGirl.create(:asset, { :facts => [
              FactoryGirl.create(:fact, :predicate => 'is', :object => 'Rack'),
              FactoryGirl.create(:fact, :predicate => 'is', :object => 'Tube')
              ]})
          end
          @asset_group.assets << @tubes_and_racks
        end

        it 'creates assets also for the overlapped assets' do
          previous_num = @asset_group.assets.count
          @step = create_step

          @asset_group.reload
          assets_created = Asset.with_fact('is', 'NewTube')
          expect(previous_num).not_to eq(@asset_group.assets.count)
          if cwm_engine?
            total_count = (@tubes_and_racks.count + @tubes.count) * (@tubes_and_racks.count + @racks.count)
            expect(assets_created.length).to eq(total_count)
            # Its 3 actions for each asset created, but the 'createdBy' relations with the 
            # asset themselves wont happen twice (this is the case only for the @tubes_and_racks
            # overlapped assets), so its 7
            total_operations = (assets_created.count*3) - @tubes_and_racks.count
            expect(Operation.all.count).to eq(total_operations)
          else
            expect(assets_created.length).to eq(previous_num)
            expect(Operation.all.count).to eq(assets_created.count)
          end
          expect(assets_created.length+previous_num).to eq(@asset_group.assets.count)

        end
      end



    end

    describe 'with unselectAsset action type' do
      setup do
        @action = FactoryGirl.create(:action, {:action_type => 'addFacts',
          :predicate => 'is', :object => 'Empty', :subject_condition_group => @cg1})
        @step_type.actions << @action
      end

      it 'unselects elements from condition group' do
        @cg1.update_attributes(:keep_selected => false)

        @asset_group.assets.reload
        assert_equal true, @tubes.all?{|tube| @asset_group.assets.include?(tube)}

        @step = create_step

        assert_equal false, @tubes.any?{|tube| @asset_group.assets.include?(tube)}
        expect(Operation.all.count).to eq(@tubes.length)
      end

      describe 'with overlapping assets' do
        setup do
          @tubes_and_racks = 7.times.map do
            FactoryGirl.create(:asset, { :facts => [
              FactoryGirl.create(:fact, :predicate => 'is', :object => 'Rack'),
              FactoryGirl.create(:fact, :predicate => 'is', :object => 'Tube')
              ]})
          end
          @asset_group.assets << @tubes_and_racks
        end

        it 'unselects the overlapped assets' do
          @cg1.update_attributes(:keep_selected => false)

          @asset_group.assets.reload
          assert_equal true, [@tubes, @tubes_and_racks].flatten.all?{|tube| @asset_group.assets.include?(tube)}

          @step = create_step

          assert_equal false, [@tubes, @tubes_and_racks].flatten.all?{|tube| @asset_group.assets.include?(tube)}
          expect(Operation.all.count).to eq([@tubes, @tubes_and_racks].flatten.length)
        end
      end


    end

    describe 'with addFacts action_type' do
      describe 'with one action' do
        setup do
          @action = FactoryGirl.create(:action, {:action_type => 'addFacts',
            :predicate => 'is', :object => 'Empty', :subject_condition_group => @cg1})
          @step_type.actions << @action
        end

        it 'adds the fact to the matched assets' do
          @asset_group.assets.reload
          @step = create_step
          @tubes.each(&:reload)
          @tubes.each do |asset|
            assert_equal true, asset.has_fact?(@action)
          end
          @racks.each(&:reload)
          @racks.each do |asset|
            assert_equal false, asset.has_fact?(@action)
          end
          expect(Operation.all.count).to eq(@tubes.length)
        end

        describe 'relating different condition groups' do
          setup do
            @action.update_attributes(:subject_condition_group => @cg1)
            @action.update_attributes(:object_condition_group => @cg2)
          end

          it 'connects 1 to N if cardinality is set to 1 in the subject condition group' do
            @asset_group.update_attributes(:assets => [@tubes.first, @racks].flatten)
            @cg1.update_attributes(:cardinality => 1)

            @step = create_step

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @racks.each do |rack|
              assert_equal true, @tubes.first.has_fact?(Struct::FakeFact.new(@action.predicate,
                  rack.relation_id))
            end
            assert_equal false, @tubes.last.has_fact?(Struct::FakeFact.new(
              @action.predicate,
              @racks.first.relation_id))
            expect(Operation.all.count).to eq(@racks.length)
          end

          it 'connects N to 1 if cardinality is set to 1 in the object condition group' do
            @asset_group.update_attributes(:assets => [@tubes, @racks.first].flatten)
            @cg2.update_attributes(:cardinality => 1)

            @step = create_step

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @tubes.each do |tube|
              assert_equal true, tube.has_fact?(Struct::FakeFact.new(@action.predicate,
                  @racks.first.relation_id))
            end
            assert_equal false, @tubes.first.has_fact?(Struct::FakeFact.new(@action.predicate,
              @racks.last.relation_id))
            expect(Operation.all.count).to eq(@tubes.length)
          end

          it 'connects 1 to 1 if cardinality is set to 1 in both subject and object condition groups' do
            @asset_group.update_attributes(:assets => [@tubes.first, @racks.first].flatten)
            @cg1.update_attributes(:cardinality => 1)
            @cg2.update_attributes(:cardinality => 1)

            @step = create_step

            @tubes.each(&:reload)
            @racks.each(&:reload)

            assert_equal true, @tubes.first.has_fact?(Struct::FakeFact.new(@action.predicate,
              @racks.first.relation_id))
            expect(Operation.all.count).to eq(1)
          end

          it 'connects N to N if no cardinality is set' do
            @asset_group.update_attributes(:assets => [@tubes, @racks].flatten)

            @step = create_step

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @tubes.each do |tube|
              @racks.each do |rack|
                assert_equal true, tube.has_fact?(Struct::FakeFact.new(@action.predicate,
                  rack.relation_id))
              end
            end
            expect(Operation.all.count).to eq(@racks.length*@tubes.length)
          end

          describe 'with overlapping assets' do
            setup do
              @tubes_and_racks = 7.times.map do
                FactoryGirl.create(:asset, { :facts => [
                  FactoryGirl.create(:fact, :predicate => 'is', :object => 'Rack'),
                  FactoryGirl.create(:fact, :predicate => 'is', :object => 'Tube')
                  ]})
              end
              @asset_group.assets << @tubes_and_racks
            end

            it 'connects overlapped assets with themselves as consequence of the condition', :last=> true do
              @asset_group.assets.reload

              @step = create_step

              @tubes.each(&:reload)
              @racks.each(&:reload)
              @tubes_and_racks.each(&:reload)

              [@tubes, @tubes_and_racks].flatten.each do |tube|
                [@racks,  @tubes_and_racks].flatten.each do |rack|
                  assert_equal true, tube.has_fact?(Struct::FakeFact.new(@action.predicate,
                    rack.relation_id))
                end
              end
              expect(Operation.all.count).to eq((@racks.length+@tubes_and_racks.length)*(@tubes.length+@tubes_and_racks.length))
            end
          end

        end
      end


      describe 'with several actions' do
        setup do
          @action = FactoryGirl.create(:action, {:action_type => 'addFacts',
            :predicate => 'is', :object => 'Empty'})
          @action2 = FactoryGirl.create(:action, {:action_type => 'addFacts',
            :predicate => 'is', :object => 'Red'})

          @step_type.actions << @action
          @step_type.actions << @action2
        end

        describe 'for the same condition group' do
          setup do
            @action.update_attributes(:subject_condition_group => @cg1)
            @action2.update_attributes(:subject_condition_group => @cg1)
          end
          it 'adds all the facts to all the assets of the condition group' do
            create_step
            @tubes.each(&:reload)
            @tubes.each do |asset|
              assert_equal true, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end
            @racks.each(&:reload)
            @racks.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal false, asset.has_fact?(@action2)
            end

            expect(Operation.all.count).to eq(2*@tubes.length)
          end
        end

        describe 'for different condition groups' do
          setup do
            @action.update_attributes(:subject_condition_group => @cg1)
            @action2.update_attributes(:subject_condition_group => @cg2)
          end

          it 'adds the specific facts to the assets of the specific condition group' do
            create_step
            @tubes.each(&:reload)
            @tubes.each do |asset|
              assert_equal true, asset.has_fact?(@action)
              assert_equal false, asset.has_fact?(@action2)
            end
            @racks.each(&:reload)
            @racks.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end
            expect(Operation.all.count).to eq(@racks.length+@tubes.length)
          end
        end


      end
    end

    describe 'with removeFacts action_type' do
      describe 'with one action' do
        setup do
          @action = FactoryGirl.create(:action, {:action_type => 'removeFacts',
            :predicate => 'is', :object => 'Tube', :subject_condition_group => @cg1})
          @step_type.actions << @action
        end

        it 'removes the fact from the matched assets', :last => true do
          @asset_group.assets.reload
          @tubes.each do |asset|
            assert_equal true, asset.has_fact?(@action)
          end
          @step = create_step
          @tubes.each(&:reload)
          @tubes.each do |asset|
            assert_equal false, asset.has_fact?(@action)
          end
          @racks.each(&:reload)
          @racks.each do |asset|
            assert_equal false, asset.has_fact?(@action)
          end
          expect(Operation.all.count).to eq(@tubes.length)
        end
      end
      describe 'relating different condition groups' do
        setup do
          # Something like removeFact(?tube :relatesTo ?rack)
          @action = FactoryGirl.create(:action, {:action_type => 'removeFacts',
            :predicate => 'relatesTo', :subject_condition_group => @cg1,
            :object_condition_group => @cg2})
          @step_type.actions << @action
        end

        it 'removes the link between both assets' do
          @tubes.first.facts << FactoryGirl.create(:fact, {
            :predicate => 'relatesTo', :object => @racks.first.relation_id,
            :object_asset => @racks.first,
            :literal => false})

          assert_equal 1, @tubes.first.facts.select{|f| f.predicate == 'relatesTo'}.length

          @asset_group.update_attributes(:assets => [@tubes.first, @racks.first].flatten)
          create_step

          @tubes.each(&:reload)
          @racks.each(&:reload)
          assert_equal 0, @tubes.first.facts.select{|f| f.predicate == 'relatesTo'}.length
          expect(Operation.all.count).to eq(1)
        end
        describe 'relating several assets' do
          it 'removes the link between all assets', :last => true do
            @tubes.each do |tube|
              @racks.each do |rack|
                tube.facts << FactoryGirl.create(:fact, {
                  :predicate => 'relatesTo', :object => rack.relation_id,
                  :object_asset => rack,
                  :literal => false})
              end
            end

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @tubes.each do |tube|
              assert_equal true, (tube.facts.select{|f| f.predicate == 'relatesTo'}.length>0)
            end

            create_step

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @tubes.each do |tube|
              assert_equal 0, tube.facts.select{|f| f.predicate == 'relatesTo'}.length
            end
            expect(Operation.all.count).to eq(@racks.length*@tubes.length)
          end

          it 'removes the link just between the matched assets', :last => true do
            @tubes.each do |tube|
              tube.facts << FactoryGirl.create(:fact, {
               :predicate => 'relatesTo', :object => @tubes.first.relation_id,
               :object_asset => @racks.first,
               :literal => false})
            end

            @racks.each do |rack|
              rack.facts << FactoryGirl.create(:fact, {
               :predicate => 'relatesTo', :object => @racks.first.relation_id,
               :object_asset => @racks.first,
               :literal => false})
            end

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @tubes.each do |tube|
              assert_equal true, (tube.facts.select{|f| f.predicate == 'relatesTo'}.length>0)
            end

            @racks.each do |rack|
              assert_equal true, (rack.facts.select{|f| f.predicate == 'relatesTo'}.length>0)
            end

            create_step

            @tubes.each(&:reload)
            @racks.each(&:reload)

            @tubes.each do |tube|
              assert_equal 0, tube.facts.select{|f| f.predicate == 'relatesTo'}.length
            end

            @racks.each do |rack|
              assert_equal 1, rack.facts.select{|f| f.predicate == 'relatesTo'}.length
            end

            expect(Operation.all.count).to eq(@tubes.length)
          end

        end
      end
      describe 'with several actions' do
        setup do
          @action = FactoryGirl.create(:action, {:action_type => 'removeFacts',
            :predicate => 'is', :object => 'Tube'})
          @action2 = FactoryGirl.create(:action, {:action_type => 'removeFacts',
            :predicate => 'is', :object => 'Full'})

          @step_type.actions << @action
          @step_type.actions << @action2
        end

        describe 'for the same condition group' do
          setup do
            @action.update_attributes(:subject_condition_group => @cg1)
            @action2.update_attributes(:subject_condition_group => @cg1)
          end
          it 'removes all the facts to all the assets of the condition group' do
            @tubes.each do |asset|
              assert_equal true, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end
            @racks.each(&:reload)
            @racks.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end

            create_step
            @tubes.each(&:reload)
            @tubes.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal false, asset.has_fact?(@action2)
            end
            @racks.each(&:reload)
            @racks.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end
            expect(Operation.all.count).to eq(2*@tubes.length)
          end
        end

        describe 'for different condition groups' do
          setup do
            @action.update_attributes(:subject_condition_group => @cg1)
            @action2.update_attributes(:subject_condition_group => @cg2)
          end

          it 'removes the specific facts to the assets of the specific condition group' do
            @tubes.each(&:reload)
            @tubes.each do |asset|
              assert_equal true, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end
            @racks.each(&:reload)
            @racks.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end

            create_step

            @tubes.each(&:reload)
            @tubes.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal true, asset.has_fact?(@action2)
            end
            @racks.each(&:reload)
            @racks.each do |asset|
              assert_equal false, asset.has_fact?(@action)
              assert_equal false, asset.has_fact?(@action2)
            end
            expect(Operation.all.count).to eq(@tubes.length+@racks.length)
          end
        end

      end
    end

  end

  
end
