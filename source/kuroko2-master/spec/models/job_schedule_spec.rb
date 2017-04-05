require 'rails_helper'

describe Kuroko2::JobSchedule do

  describe '#valid?' do
    it 'accepts only CRON notation' do
      expect(Kuroko2::JobSchedule.new(cron: '* * * * *')).to be_valid
      expect(Kuroko2::JobSchedule.new(cron: '1,2-3,*,*/4,5-6/7 1,2-3,*,*/4,5-6/7 1,2-3,*,*/4,5-6/7 1,2-3,*,*/4,5-6/7 1,2-3,*,*/4,1-3/5')).to be_valid
      expect(Kuroko2::JobSchedule.new(cron: '* * * *')).not_to be_valid
    end

    it 'accepts only valid CRON notation' do
      expect(Kuroko2::JobSchedule.new(cron: '5-0 * * * *')).not_to be_valid
    end
  end

  describe '#next' do
    let(:cron) { '0,15,30,45 10 * * *' }
    let(:definition) { create(:job_definition) }
    let(:schedule) { create(:job_schedule, job_definition: definition, cron: cron) }
    let(:time) { Time.new(2016, 1, 1, 10, 0) }

    context 'Without suspend_schelule' do
      it 'returns next schedule' do
        expect(schedule.next(time)).to eq(Time.new(2016, 1, 1, 10, 15))
      end
    end

    context 'With suspend_schelule' do
      before do
        create(:job_suspend_schedule, job_definition: definition, cron: '0-29 10 * * *')
      end

      it 'skips suspend time range' do
        expect(schedule.next(time)).to eq(Time.new(2016, 1, 1, 10, 30))
      end
    end

    context 'When suspend schelules covers all schedule' do
      before do
        create(:job_suspend_schedule, job_definition: definition, cron: '0-50 10 * * *')
      end

      it 'returns nil' do
        expect(schedule.next(time)).to be_nil
      end
    end

    context 'With invalid date' do
      let(:cron) { '* * 31 2 *' }
      let(:time) { Time.new(2016, 2, 28, 10, 0) }
      xit 'occurs infinit loop (https://github.com/r7kamura/chrono/issues/2)' do
        expect(schedule.next(time)).to eq(Time.new(2016, 1, 1, 10, 15))
      end
    end
  end

  describe '.launch_scheduled_jobs!' do
    let(:definition) { create(:job_definition) }
    let(:time_from) { Time.new(2016, 1, 1, 9, 50, 0) }

    before do
      create(:job_schedule, job_definition: definition, cron: '0 10 * * *')
    end

    context 'Without scheduled time' do
      let(:time_to) { Time.new(2016, 1, 1, 9, 58, 0) }

      it 'does not launch jobs' do
        expect { Kuroko2::JobSchedule.launch_scheduled_jobs!(time_from, time_to) }.
          not_to change { Kuroko2::JobInstance.count }
      end
    end

    context 'With scheduled time' do
      let(:time_to) { Time.new(2016, 1, 1, 10, 1, 0) }

      it 'launches jobs' do
        expect { Kuroko2::JobSchedule.launch_scheduled_jobs!(time_from, time_to) }.
          to change { Kuroko2::JobInstance.count }.from(0).to(1)
      end

      context 'With suspended option' do
        before do
          definition.update!(suspended: true)
        end

        it 'does not launch jobs' do
          expect { Kuroko2::JobSchedule.launch_scheduled_jobs!(time_from, time_to) }.
            not_to change { Kuroko2::JobInstance.count }
        end
      end
    end

    context 'With job_suspend_schedule' do
      before do
        create(:job_schedule, job_definition: definition, cron: '* 10 * * *')
        create(:job_suspend_schedule, cron: '0-30 10 * * *', job_definition: definition)
      end

      context 'On supended time' do
        let(:time_from) { Time.new(2016, 1, 1, 9, 50, 0) }
        let(:time_to)   { Time.new(2016, 1, 1, 10, 1, 0) }

        it 'does not launch jobs' do
          expect { Kuroko2::JobSchedule.launch_scheduled_jobs!(time_from, time_to) }.
            not_to change { Kuroko2::JobInstance.count }
        end
      end

      context 'Out of supended time' do
        let(:time_from) { Time.new(2016, 1, 1, 10, 30, 0) }
        let(:time_to)   { Time.new(2016, 1, 1, 10, 31, 0) }
        it 'launches jobs' do
          expect { Kuroko2::JobSchedule.launch_scheduled_jobs!(time_from, time_to) }.
            to change { Kuroko2::JobInstance.count }.from(0).to(1)
        end
      end
    end
  end
end
