module SyllabusHelpers
	class << self
		def registered(app)
			app.send :include, Helpers
			#app.set :syllabus_display, SyllabusDisplayManager.new
		end
		alias :included :registered
	end
	
	module Helpers
		def syllabus_display
			@_syllabus_display_manager ||= SyllabusDisplayManager.new
		end
		
		# All of these print_x functions more or less just call partials, but we have functions in case we need
		# to do anything else as well as call the partial. It just makes more sense to have this level of
		# modularity.
		def print_week
			locals = {
				:week_number => syllabus_display.current_week,
				:content => syllabus_display.current_week_content,
				:week_title => syllabus_display.week_title
			}
			# Handle printing a week. Also, clears out the buffers.
			clean_up_week

			partial("syllabus_partials/print_week", :locals => locals)

		end

		def print_row_title(title)
			partial "syllabus_partials/print_row_title", :locals => {:row_title => title}
		end

		def print_day(date, content)
			if date.class == String
				begin
					date = Date.parse(date)
				rescue ArgumentError
					return nil
				end
			end
			# Handle printing a day.
			partial("syllabus_partials/print_day", :locals => { :content => content, :date => date })
		end

		def print_holiday(date, holiday_name)
			# Handle printing a holiday
			print_day(date, partial("syllabus_partials/print_holiday", :locals => {:holiday_name => holiday_name, :date => date}))
		end

		def begin_syllabus(variables={})
			# Print out any HTML that needs to be at the top of the syllabus.
			partial("syllabus_partials/print_begin_syllabus", :locals => variables)
		end

		def end_syllabus(variables={})
			# Print out any HTML that needs to be at the bottom of the syllabus.

			# Also, in this method, we call print_week to clear out any output buffers.
			value = print_week + partial("syllabus_partials/print_end_syllabus", :locals => variables)

			syllabus_display.class_days = []
			syllabus_display.noclass_dates = []
			syllabus_display.holidays = {}
			syllabus_display.start_date = nil
			syllabus_display.current_date = nil
			syllabus_display.current_day = nil
			syllabus_display.previous_day = nil
			syllabus_display.current_week = 1
			syllabus_display.current_week_content = ""
			syllabus_display.week_title = ""
			syllabus_display.next_week_title = nil

			return value
		end

		def week_title(title)


			# Detect if syllabus_display.week_title is being called before a new week starts (which would attach it to the wrong week)
			if syllabus_display.current_day == 0
				# If the function is called twice in a week (which could happen if one week was labelled at the end of
				# the week and the second was labelled at the beginning), assume first call is current week and second
				# is for next week.
				if !syllabus_display.next_week_title.nil?
					syllabus_display.week_title = syllabus_display.next_week_title
				end
				syllabus_display.next_week_title = title
			else
				# Detect if the call to syllabus_display.week_title is actually called during the middle of the week or actually called
				# for the next week on a week that ends in a holiday (because of the way syllabus_display.holidays are handled, a week
				# ending in a holiday won't scan the same way as a week that does not end with a holiday).
				if !syllabus_display.current_day.nil?
					current_day = syllabus_display.class_days[syllabus_display.current_day]
					if !syllabus_display.holidays[(syllabus_display.current_date + (current_day - syllabus_display.previous_day)).to_s].nil?
						syllabus_display.next_week_title = title
					else
						syllabus_display.week_title = title
					end
				else
					syllabus_display.week_title = title
				end
			end
		end

		def class_meets_on(day)
			# Set the day of the week that class meets. Input must be the full name of the day.
			class_day = Date::DAYNAMES.index(day.capitalize)
			if !class_day.nil? && syllabus_display.class_days.index(class_day).nil?
				syllabus_display.class_days.push(class_day)
			end
			syllabus_display.class_days.sort!
		end

		def no_class_on_day(date)
			# This method marks a date as not having classes.
			#
			# You could, in theory, have a class cancelled and it not be a holiday. If so, you would call this
			# method instead of holiday. There really isn't a good reason to do this (because the date just 
			# won't) show up on the schedule, but it could become important for some reason.
			#
			# Partly, this results because of the fact that this package is a port of LaTeX's termcal package 
			# (but not really) and, in termcal, you have to use the noclass stuff because termcal doesn't do a
			# great job of detecting if there's a difference between when classes start and when your course
			# starts (also, in termcal, you *have* to start classes on a Monday (fascists)). So, anyway, this
			# method is not super-useful, but it's better to have it and not need it then need it and not have
			# it.

			# Parse the string the user gives us into a Date object. If the string isn't actually a date, we
			# ignore the call to the function and throw it out.
			begin
				date = Date.parse(date)
			rescue ArgumentError
				return nil
			end

			# Add the date to the list of of dates when class doesn't met.
			syllabus_display.noclass_dates.push(date)
			return date	
		end

		def holiday(date, name)
			# This method schedules a holiday.

			# First we mark the date as being one on which class doesn't happen.
			no_class_on_day(date)

			# We need to parse the date to make sure it's actually a date and not badly formatted junk.
			# This function will ignore it if the user attempts to pass in an incorrectly formatted
			# date.
			begin
				date = Date.parse(date)
			rescue ArgumentError
				return nil
			end

			# Add the name of the holiday to our hash of syllabus_display.holidays.
			syllabus_display.holidays[date.to_s] = name
		end

		def start_day(date)
			# This is the method where the user sets the date on which classes are scheduled to start. This program
			# is set up such that users don't actually have to enter the date their class starts (which could be different),
			# merely the day on which classes are scheduled to start at the university.

			# Convert the date from a String to a Date object. If the String is invalid, raise an error that 
			# will hopefully help explain things to our users.
			begin
				syllabus_display.start_date = Date.parse(date)
			rescue ArgumentError
				raise ArgumentError, "<h2>It looks as if the starting date you provided for this course is not readable by a computer. <br/><br/>Please see <a href=\"http://ruby-doc.org/stdlib-1.8.7/libdoc/date/rdoc/Date.html#method-c-parse\">the documentation</a> for more information.</h2>"
			end

			syllabus_display.current_date = syllabus_display.start_date
		end	

		def clean_up_week
			# Reset all the week information after a week is printed to HTML
			syllabus_display.current_week += 1
			syllabus_display.current_week_content = ""
			if !syllabus_display.next_week_title.nil?
				syllabus_display.week_title = syllabus_display.next_week_title
				syllabus_display.next_week_title = nil
			else
				syllabus_display.week_title = ""
			end
		end

		def advance_date
			# Advance the date, but only if syllabus_display.previous_day is defined. We check this because this function
			# will get called the first time through, when we actually don't want to advance the date (because
			# we're on the first day).
			if !syllabus_display.previous_day.nil?
				# Figure out what day of the week we are on.
				current_day = syllabus_display.class_days[syllabus_display.current_day]
				# If syllabus_display.previous_day is larger, we've gone from, say, Friday to Monday and have to adjust (as days are numbered 0-6)
				if syllabus_display.previous_day > current_day
					syllabus_display.current_date += ((Date::DAYNAMES.length - syllabus_display.previous_day) + (current_day))
				# Otherwise, the calculation is easy
				else
					syllabus_display.current_date += (current_day-syllabus_display.previous_day)
				end
			end
		end

		def advance_day	
			# Advance to the next day. If we are at the end of the week, reset to zero to indicate the week starting
			# over.
			# Also, we track previous day, because we need it in the advance_date method.
			syllabus_display.previous_day = syllabus_display.class_days[syllabus_display.current_day]
			if syllabus_display.current_day == (syllabus_display.class_days.length - 1)
				syllabus_display.current_day = 0
			else
				syllabus_display.current_day += 1
			end
		end

		def class_day(content)
			# User's call this method to schedule lesson activities for a specific day.
			#
			# Due to the complex way in which time works, I don't fully understand *why* this method works.
			# However, it does work. Partly, the problem has to do with the way with the (kind of overly 
			# simplistic) way HAML does EVERYTHING. Also, there doesn't appear to be an easy way to do
			# a print buffer, so essentially what we do is cache all the output for a given week of classes
			# and then print it when the week ends.
			#
			# As such, you have the variable "output" containing the actual stuff to get printed, but it is
			# only ever filled with data at the end of the week (which is tough to detect because we aren't
			# always dealing with weeks that end on a Friday or a Saturday or whatever (thanks academic 
			# scheduling)).

			# Content formatted using Markdown:
			# content = Haml::Filters::Markdown.render(content)

			# We may have to fill this with output (but only when a week ends)
			output = ""

			# If there isn't a syllabus_display.current_date, that means the user hasn't called syllabus_display.start_date, so we
			# can't actually run this method.
			if syllabus_display.current_date.nil?
				return content_tag(:em) { "You have not set a start date." }
			end

			# If syllabus_display.current_day is nil, that means we are on the first day of a syllabus, so we have
			# to do a little house keeping to set things up.
			if syllabus_display.current_day.nil?
				# Figure out which class meeting day the first day of class is:
				syllabus_display.current_day = syllabus_display.class_days.index(syllabus_display.start_date.wday)
				# But, wait! Classes don't always start on the first day a class may meet (Think classes
				# starting on a Monday but teaching a Tuesday / Thursday) schedule. We have to move through
				# the calendar, starting from when classes are scheduled to begin, until we find the first date 
				# a course actually meets.
				while syllabus_display.current_day.nil?
					# We iterate syllabus_display.current_date instead of syllabus_display.start_date because there could be a reason to
					# preserve the actual starting date for all courses, university-wide.
					syllabus_display.current_date += 1
					syllabus_display.current_day = syllabus_display.class_days.index(syllabus_display.current_date.wday)
				end
			# If we are on the first day of a week (syllabus_display.current_day = 0), print the previous week.
			elsif syllabus_display.current_day == 0
				output = print_week	
			end

			advance_date

			# Check for days where class doesn't meet:
			while !syllabus_display.noclass_dates.index(syllabus_display.current_date).nil? do
				advance_day
				# If there is a record for a holiday, print it.
				if !syllabus_display.holidays[syllabus_display.current_date.to_s].nil?
					syllabus_display.current_week_content += print_holiday(syllabus_display.current_date, syllabus_display.holidays[syllabus_display.current_date.to_s])
					advance_date
					if syllabus_display.current_day == 0
						output += print_week
					end
				end
			end	

			advance_day
			syllabus_display.current_week_content += print_day(syllabus_display.current_date, content)
			return output
		end

		def unit_title(title)
			syllabus_display.current_week_content += print_row_title(title)
			return ""
		end
	end
	::Middleman::Extensions.register(:syllabus_helpers, SyllabusHelpers)
	
	class SyllabusDisplayManager
		attr_accessor :class_days, :noclass_dates, :holidays, :start_date, :current_date, :current_day, :previous_day, :current_week, :current_week_content, :week_title, :next_week_title, :print_week_names
		def initialize
			# The list of days on which a given class will meet. The numbers in this array correspond to days of
			# the week, from Sunday-Saturday (0-6).
			@class_days = []
			# Specific dates when class doesn't meet. We have two records of days when classes don't meet (this and
			# syllabus_display.holidays, below) because there could be a time when class doesn't meet but it is not a holiday (in 
			# other words, you want a day to just not appear on the syllabus).
			#
			# This array stores the master list of all days when classes don't meet.
			@noclass_dates = []
			# This hash uses the result of Date.to_s as the key and contains the name of the holiday (or reason a 
			# class is cancelled).
			@holidays = {}
			# A Date object containing the date classes start. This can be the date classes start university-wide,
			# not just the date a specific class meets.
			@start_date = nil
			# This variable will keep track of the date as we iterate through the semester.
			@current_date = nil
			# This variable keeps track of the current index of syllabus_display.class_days being worked on.
			@current_day = nil
			# Tracks the previous day of the week (0-6) worked on.
			@previous_day = nil
			# The current week of the semester
			@current_week = 1
			# The buffer that stores week content.
			@current_week_content = ""

			@print_week_names = true

			@week_title = ""
			@next_week_title = nil
		end
	end
end