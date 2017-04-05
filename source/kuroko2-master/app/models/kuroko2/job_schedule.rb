class Kuroko2::JobSchedule < Kuroko2::ApplicationRecord
  include Kuroko2::TableNameCustomizable

  belongs_to :job_definition

  CRON_FORMAT = /\A
    (?:[1-5]?[0-9]|(?:[1-5]?[0-9]\-[1-5]?[0-9]|\*)(?:\/[1-5]?[0-9])?)(?:,(?:[1-5]?[0-9]|(?:[1-5]?[0-9]\-[1-5]?[0-9]|\*)(?:\/[1-5]?[0-9])?))*
    \s+
    (?:1?[0-9]|2[0-3]|(?:(?:1?[0-9]|2[0-3])\-(?:1?[0-9]|2[0-3])|\*)(?:\/(?:1?[0-9]|2[0-3]))?)(?:,(?:1?[0-9]|2[0-3]|(?:(?:1?[0-9]|2[0-3])\-(?:1?[0-9]|2[0-3])|\*)(?:\/(?:1?[0-9]|2[0-3]))?))*
    \s+
    (?:(?:[1-9]|[1-2][0-9]|3[0-1])|(?:(?:[1-9]|[1-2][0-9]|3[0-1])\-(?:[1-9]|[1-2][0-9]|3[0-1])|\*)(?:\/(?:[1-9]|[1-2][0-9]|3[0-1]))?)(?:,(?:(?:[1-9]|[1-2][0-9]|3[0-1])|(?:(?:[1-9]|[1-2][0-9]|3[0-1])\-(?:[1-9]|[1-2][0-9]|3[0-1])|\*)(?:\/(?:[1-9]|[1-2][0-9]|3[0-1]))?))*
    \s+
    (?:(?:[1-9]|1[0-2])|(?:(?:[1-9]|1[0-2])\-(?:[1-9]|1[0-2])|\*)(?:\/(?:[1-9]|1[0-2]))?)(?:,(?:(?:[1-9]|1[0-2])|(?:(?:[1-9]|1[0-2])\-(?:[1-9]|1[0-2])|\*)(?:\/(?:[1-9]|1[0-2]))?))*
    \s+
    (?:[0-6]|(?:(?:[0-6]\-[0-6]|\*)(?:\/[0-6])?))(?:,(?:[0-6]|(?:(?:[0-6]\-[0-6]|\*)(?:\/[0-6])?)))*
  \z/x

  validates :cron, format: { with: CRON_FORMAT }, uniqueness: { scope: :job_definition_id }
  validate :validate_cron_schedule

  def next(now = Time.current)
    if 1.month.ago(now).future?
      Kuroko2.logger.warn("Exceeds the time of criteria #{now}. (Up to 1 month since)")
      return
    end

    next_time = Chrono::Iterator.new(self.cron, now: now).next
    suspend_times = suspend_times(now, next_time)

    if suspend_times.include?(next_time)
      self.next(next_time)
    else
      next_time
    end
  end

  def scheduled_times(time_from, time_to)
    it = Chrono::Iterator.new(cron, now: time_from)
    scheduled_times = []

    loop do
      next_time = it.next
      if next_time <= time_to
        scheduled_times << next_time
      else
        break
      end
    end

    scheduled_times.map(&:in_time_zone)
  end

  def suspend_times(time_from, time_to)
    if job_definition && job_definition.job_suspend_schedules.present?
      job_definition.job_suspend_schedules.
        map { |schedule| schedule.suspend_times(time_from, time_to) }.flatten.uniq
    else
      []
    end
  end

  private

  def validate_cron_schedule
    if CRON_FORMAT === cron
      self.next
    end
    nil
  rescue Chrono::Fields::Base::InvalidField => e
    errors.add(:cron, "has invalid field: #{e.message}")
  end

  def self.launch_scheduled_jobs!(time_from, time_to)
    includes(job_definition: :job_suspend_schedules).find_each do |schedule|
      definition = schedule.job_definition
      suspend_times = schedule.suspend_times(time_from, time_to)

      schedule.scheduled_times(time_from, time_to).each do |time|
        if definition.suspended?
          Kuroko2.logger.info("Skipped suspended \"##{definition.id} #{definition.name}\" that is scheduled at #{I18n.l(time, format: :short)} by `#{schedule.cron}`")
        elsif suspend_times.include?(time)
          Kuroko2.logger.info("Skipped schedule suspended \"##{definition.id} #{definition.name}\" that is scheduled at #{I18n.l(time, format: :short)} by `#{schedule.cron}`")
        else
          launched_by = "\"##{definition.id} #{definition.name}\" that is scheduled at #{I18n.l(time, format: :short)} by `#{schedule.cron}`"
          definition.create_instance(launched_by: launched_by)
        end
      end
    end
  end
end
