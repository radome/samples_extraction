require 'rails_helper'
require 'inferences_helper'

RSpec.describe :cancellable, cancellable: true do
  setup do
    @asset_group = FactoryGirl.create :asset_group
    @activity_type = FactoryGirl.create :activity_type
    @activity = FactoryGirl.create :activity, activity_type: @activity_type, asset_group: @asset_group
    @steps = 10.times.map do 
      step = build_step(%Q{{?p :maxCardinality "1".} => {:step :createAsset {?p :a :Tube .}.} .}, %Q{}, activity: @activity)
      step.update_attributes(state: 'complete')
      step
    end
  end

  it 'cancels all the operations of the step when cancelling the step' do
    expect(@steps[0].operations.any?(&:cancelled?)).to eq(false)
    @steps[0].cancel
    @steps.each(&:reload)
    expect(@steps[0].operations.all?(&:cancelled?)).to eq(true)
  end

  it 'redoes all the operations of the step when redoing the step' do
    expect(@steps[0].operations.any?(&:cancelled?)).to eq(false)
    @steps[0].cancel
    @steps.each(&:reload)
    expect(@steps[0].operations.all?(&:cancelled?)).to eq(true)

    @steps[0].remake
    @steps.each(&:reload)
    expect(@steps[0].operations.all?(&:cancelled?)).to eq(false)
  end  

  it 'cancels your step and all the steps newer than it' do
    expect(@steps.any?{|s| s.cancelled?}).to eq(false)
    @steps[5].cancel
    @steps.each(&:reload)
    expect(@steps.select{|s| s.cancelled?}.count).to eq(5)
    expected_ids = [@steps[5].id, @steps[5].steps_newer_than_me.map(&:id)].flatten.sort
    expect(@steps.select{|s| s.cancelled?}.map(&:id).sort).to eq(expected_ids)
  end

  it 'redoes your step and all the steps older than it' do
    expect(@steps.any?{|s| s.cancelled?}).to eq(false)
    @steps[5].cancel
    @steps.each(&:reload)
    expect(@steps.select{|s| s.cancelled?}.count).to eq(5)
    expected_ids = [@steps[5].id, @steps[5].steps_newer_than_me.map(&:id)].flatten.sort
    expect(@steps.select{|s| s.cancelled?}.map(&:id).sort).to eq(expected_ids)

    @steps[9].remake
    @steps.each(&:reload)
    expect(@steps.any?{|s| s.cancelled?}).to eq(false)
  end

  it 'deprecates all cancelled steps on step creation' do
    expect(@steps.any?{|s| s.cancelled?}).to eq(false)
    @steps[5].cancel
    @steps.each(&:reload)
    expect(@steps.select{|s| s.cancelled?}.count).to eq(5)
    expected_ids = [@steps[5].id, @steps[5].steps_newer_than_me.map(&:id)].flatten.sort
    expect(@steps.select{|s| s.cancelled?}.map(&:id).sort).to eq(expected_ids)

    build_step(%Q{{?p :maxCardinality "1".} => {:step :createAsset {?p :a :Tube .}.} .}, %Q{}, activity: @activity)
    @activity.steps.each(&:reload)
    expect(@activity.steps.count).to eq(6)
  end

end