require 'set'

class ApplicationController < ActionController::Base

  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Filter Needed for CalNet Login
  before_filter CASClient::Frameworks::Rails::Filter
  before_action :require_info, :except => [:welcome, :all_courses, :all_emails, :create]
  before_action :get_info, :except => :create

  def require_info
    user_exists = User.find_by(uid: session[:cas_user]) != nil
    if not user_exists
      redirect_to "/welcome" and return
    end
  end

  def get_info
    @user = User.find_by(uid: session[:cas_user])
    @user_exists = @user != nil
    @all_courses = Course.all_courses
    @all_emails = User.all_emails
  end

  def logout
    CASClient::Frameworks::Rails::Filter.logout(self)
    session.clear and return
  end

  # Displays a page to allow the user to enter information
  def welcome
    redirect_to "/user" and return if @user_exists
    render "welcome", layout: false and return
  end

  def specific_class
    @course = Course.find(params[:id])
    all_prereqs = @course.compute_prereqs_given_user(@user)
    @remaining_prereqs = all_prereqs[0]
    @finished_prereqs = all_prereqs[1]

    @professorCourses = ProfessorCourse.where(number: @course.number)
    @professors = Set.new
    @professorCourses.each do |professorCourse|
      @professors << professorCourse.professor
    end
    @professors = @professors.sort_by { |professor| -professor.rating}
  end

  def classes
  end

  def professors
    @all_profs = Professor.all_profs
  end

  def dist_profs
    @dist_profs = Professor.dist_profs
  end

  def all_courses
    render :text => @all_courses.to_json
  end

  def all_emails
    render :text => @all_emails.to_json
  end

  def create
    @user = User.create(first_name: params[:first_name],
                        last_name: params[:last_name], email: params[:email],
                                                        uid: session[:cas_user])
    if !@user.valid?
      @user = User.find_by(uid: session[:cas_user])
    end
    if params[:class_select] != nil
      params[:class_select].each do |course|
        attrs = Utils.split_by_colon(course)
        if @user.user_courses.find_by(title: attrs[0]).nil?
          @user.user_courses.create(title: attrs[0], number: attrs[1], taken: true)
        end
      end
    end

    redirect_to "/user" and return
  end

  def index
  end

  def edit
    @user_classNames = []
    @user_takenClassNames = []
    @user.user_courses.each do |course|
      if course.taken
        @user_takenClassNames << course.number
      end
      @user_classNames << course.number
    end
  end

  def update
    @user.user_courses.destroy_all
    taken_classes = params[:taken_classes]

    if params[:classes] != nil
      params[:classes].each_key do |course|
        attrs = Utils.split_by_colon(course)
        begin
          taken = taken_classes.include?(course)
        rescue
          taken = false
        end
        @user.user_courses.create(title: attrs[0], number: attrs[1], taken: taken)
      end
    end

    redirect_to "/user" and return
  end

end
