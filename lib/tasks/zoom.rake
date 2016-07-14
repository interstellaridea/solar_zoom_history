
### API ZOOM WRAPPER ###
# Creates
def zoomAPI( endpoint, params = {} )
  # Environment Vars
  apiKey = ENV['Zoom_API_Key']
  apiSecret = ENV['Zoom_API_Secret']
  baseUri = "https://api.zoom.us/"
  dataType = "data_type=JSON"
  version = 'v1/'
  results = Array.new

  # Adds Key, Secret and DataType to passed Array
  results = [
    "api_key=#{apiKey}",
    "api_secret=#{apiSecret}",
    "#{dataType}"
  ]
  # ADD go through hash and push key and values to results array
  params.each do |key, value|
    results.push("#{key}=#{value}")
  end

  # Create and reurn one Url for HTTPARY to use
  url = "#{baseUri}" + "#{version}" +  "#{endpoint}" + "?" +  results.join('&')
  return url
end
### ### ###

### Add capitalize? methods to string class ###
class String
  def capitalized?
    chars.first == chars.first.upcase
  end
end
### ### ###
## Check for valid string DateTime, flip to datetime
def valid_time(time)
  time.empty? ? time = "N/A" : time = DateTime.parse(time)
end
### #### ###



namespace :zoom do

  desc "Get Zoom User ID using email"
  task :id_by_email, [:email] => :environment do |item ,args|
    # Create API request
    url = zoomAPI( 'user/getbyemail', :login_type=>101, :email=>"#{args.email}" )
    # POST request to Zoom base API URL
    response = HTTParty.post(url)
    # Save ID
    id = response['id']

    print " USER ID is : #{id}"
    print "\n"
  end

  desc "Creates users from zoom and loads to dev db, takes count"
  task :load_users, [:number] => :environment do |items, args|
    user = ''
    # Create url to POST to zoom
    url = zoomAPI('user/list', :page_size => args.number)

    print "Rake will load #{args.number} zoom users into the db"
    print "\n"
    # Print toal number of users
    response = HTTParty.post( url )
    print "Zooms current total users are #{response['total_records']}"
    print "\n"
    # Create a user from the zoom USER list
    response['users'].each do |user|
      user = User.new(
      :zoom_id=>user['id'],
      :first_name =>user['first_name'],
      :last_name =>user['last_name'],
      :email =>user['email'],
      :pmi =>user['pmi'],
      :enable_large =>user['enable_large'],
      :large_capacity =>user['large_capacity'],
      :enable_webinar =>user['enable_webinar'],
      :webinar_capacity =>user['webinar_capacity']
      )
      #Validate if the user exists in the database
      if user.valid?
        user.save
        print "#{user['first_name']} Create in Local Database!"
        print "\n"
      else
        print "#{user['email'].split("@")[0]} - > #{user.errors.messages}"
        print "\n"
      end
    end
  end

  desc "Creates meetings to db from specifed time"
  task :get_meetings, [:when, :period, :number] => :environment do |items, args|
    from = ''
    to = ''

    # Handle users input from when EX: jan -> Jan
    "#{args.when}".capitalized? ? month = "#{args.when}" : month = "#{args.when}".capitalize

    # Get integer of argument month
    month = Date::ABBR_MONTHNAMES.index(month)

    # Get the current day
    now = Date.today()
    if args.period == "all"
      from = Date.new( now.year, month, 1 )
      to = Date.new( now.year, month, 1 ).next_month.prev_day
    elsif args.period == "today"
      from = Date.new( now.year, month, 1 )
      to = Date.new( now.year, month, now.day + 1)
    end
    print "You want meetings from : #{from} => #{to} \n"
    print "You said you only want #{args.number} meeting(s) \n"

    # Create URL to POST to ZOOM API
    meet_url = zoomAPI(
      'metrics/meetings',
      :type=>2,
      :from => from,
      :to => to,
      :page_size=>args.number )
    response = HTTParty.post( meet_url )
    print "There are a total of: #{response['total_records']} for #{args.when} \n"
    print "\n"
    if response.code == 200
      # CREATE meetings in DB
      response['meetings'].each do |item|
        meeting = Meeting.new.extend(MeetingRepresenter).from_hash(item)
        print "\n"
        print "***** MEETING ***** \n"
        print "UUID: #{meeting['uuid']} \n"
        print "HOST: #{meeting['host_email']} \n"
        print "Participants: #{meeting['participant_count']} \n"
        print "\n"

        # Get more Detail of meeting plus all participants
        participant_url = zoomAPI(
          'metrics/meetingdetail',
          :meeting_id => URI.escape(meeting['uuid'], /\W/),
          :type => 2,
          :page_size => 300
        )
        print participant_url 
        print "\n"
        print "\n"

        participant_response = HTTParty.post( participant_url )
        participant_response = participant_response.parsed_response
        unless participant_response['participants'].nil?
          participant_response['participants'].each do |user|
            participant = Participant.new(:uuid =>participant_response['uuid'], :id_of_meeting=>participant_response['id']).extend(ParticipantRepresenter).from_hash(user)
            print "***** PARTICIPANT ***** \n"
            print "UUID : #{participant['uuid']} \n"
            print "NAME: #{participant['user_name']} \n"
            print "LEFT: #{participant['leave_time']} \n"
            print "\n"
            if participant.valid?
              participant.save
              print "***** #{participant['user_name']} SAVED! ***** \n \n"
            else
              print "#{participant.errors.messages} \n"
            end
          end
          print "***** END MEETING ***** \n \n"
        else
          print "NO Participants for #{meeting.uuid} \n"
        end
        if meeting.valid?
          meeting.save
          print "***** #{meeting['uuid']} SAVED! ***** \n"
        else
          print "#{meeting.errors.messages} \n"
          print "\n"
        end
      end
    else
      print "There was an issue with : #{meeting['uuid']} as the participants are empty \n"
      print "\n"
      print "\n"
    end
  end

  desc "A test task for debugging"
  task :test, [:word] => :environment do |items, args|


    from = ''
    to = ''

    print month
    # Get integer of argument month
    month = Date::ABBR_MONTHNAMES.index(month)

  end

















end