# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  helper :all # include all helpers, all the time
  helper_method :url_for_content, :current_user, :logged_in?

  protect_from_forgery
  filter_parameter_logging :password, :password_confirmation

  before_filter :seo_filter

protected

  def seo_filter
    @title    = %w(LinuxFr.org)
    @keywords = %w(Linux Logiciel Libre GNU Free Software Actualité Forum Communauté)
    @feeds    = {}
  end

  def current_user
    # TODO
  end

  def logged_in?
    !!current_user
  end

  def admin_required
    (logged_in? && current_user.admin?) || access_denied
  end

  def amr_required
    (logged_in? && current_user.amr?) || access_denied
  end

  def redirect_to_content(content)
    redirect_to url_for_content(content)
  end

  def url_for_content(content)
    case content
    when Post: url_for([content.forum, content])
    when News: content.new_record? ? news_index_path : url_for(content)
    else       url_for(content)
    end
  end

  def on_the_first_page?
    params[:page].to_i <= 1
  end

end
