class Priority::ReportsController < Priority::PrioritiesController
  before_action :authorize_super_admin,only: [:historical_visualization]
  layout "priority_fluid"
  # respond_to :js, :json, :html

  def index
  end

  def age_and_dollars_by_assignment
    if request.xhr?
      if params[:value] == "age_dollar_button" && params[:filter] == "age_all_button"
        render :json => Report.patient_accounts_age_by_assignment(current_user, {:filter => "all", :query => "sum"}, user_local_date_sql)
      end
      if params[:value] == "dollar_sum_button" && params[:filter] == "dollar_all_button"
        render :json => Report.patient_accounts_dollars_by_assignment(current_user, {:filter => "all", :query => "sum"}, user_local_date_sql)
      end
      if params[:value] == "age_count_button" && params[:filter] == "age_due_button"
        render :json => Report.patient_accounts_age_by_assignment(current_user, {:filter => "due", :query => "count"}, user_local_date_sql)
      end
      if params[:value] == "dollar_count_button" && params[:filter] == "dollar_due_button"
        render :json => Report.patient_accounts_dollars_by_assignment(current_user, {:filter => "due", :query => "count"}, user_local_date_sql)
      end
      if params[:value] == "age_dollar_button" && params[:filter] == "age_due_button"
        render :json => Report.patient_accounts_age_by_assignment(current_user, {:filter => "due", :query => "sum"}, user_local_date_sql)
      end
      if params[:value] == "dollar_sum_button" && params[:filter] == "dollar_due_button"
        render :json => Report.patient_accounts_dollars_by_assignment(current_user, {:filter => "due", :query => "sum"}, user_local_date_sql)
      end
      if params[:value] == "age_count_button" && params[:filter] == "age_all_button"
        render :json => Report.patient_accounts_age_by_assignment(current_user, {:filter => "all", :query => "count"}, user_local_date_sql)
      end
      if params[:value] == "dollar_count_button" && params[:filter] == "dollar_all_button"
        render :json => Report.patient_accounts_dollars_by_assignment(current_user, {:filter => "all", :query => "count"}, user_local_date_sql)
      end
    else
      @age_by_assignment_by_count = Report.patient_accounts_age_by_assignment(current_user, {:filter => "all", :query => "count"}, user_local_date_sql)
      @dollars_by_assignment_by_count = Report.patient_accounts_dollars_by_assignment(current_user, {:filter => "all", :query => "count"}, user_local_date_sql)
    end
  end

  def disposition_usage
    search_params = params[:search]
    if search_params
      sql = build_user_and_date_sql_with_b(search_params)
      @disposition_usage = Report.disposition_usage(sql[:date_condition], sql[:nested_date_condition], sql[:user_condition], sql[:nested_user_condition])
    else
      @disposition_usage = []
    end
  end

  def historical_visualization

    if params[:search]
      account_id = params[:search][:account_id]
    @historical_account_balance = ActiveRecord::Base.connection.execute("SELECT process_date, account_balance FROM historical_account_balances WHERE account_id = '#{account_id}' ORDER BY process_date").entries
    @historical_account_data = @historical_account_balance.map{|item| {x:item[0],y:item[1],z:20}}.select{ |item| item[:x] != nil }
    @all_dates = @historical_account_data.map{|item| item[:x]}

    @claim_headers = ActiveRecord::Base.connection.execute("SELECT account_number, claim_submission_date, claim_total_charges FROM claim_headers WHERE account_number = '#{account_id}'").entries
    @claim_data = @claim_headers.map{|item| {x:item[1],y:item[2],z:20}}.select{ |item| item[:x] != nil }
    @all_dates += @claim_data.map{|item| item[:x]}

    @remit_headers = ActiveRecord::Base.connection.execute("SELECT account_number, IF(check_date='0000-00-00',remit_date,check_date), remit_total_payment FROM remit_headers WHERE account_number = '#{account_id}'").entries
    @remit_data = @remit_headers.map{|item| {x:item[1],y:item[2],z:20}}.select{ |item| item[:x] != nil }
    @all_dates += @remit_data.map{|item| item[:x]}

    @charges = ActiveRecord::Base.connection.execute("SELECT account_number, post_date, amount FROM charges WHERE account_number = '#{account_id}'").entries
    @charges_data = @charges.map{|item| {x:item[1],y:item[2],z:20}}.select{ |item| item[:x] != nil }
    @all_dates += @charges_data.map{|item| item[:x]}

    @transactions = ActiveRecord::Base.connection.execute("SELECT account_number, post_date, amount FROM transactions WHERE account_number = '#{account_id}'").entries
    @transactions_data = @transactions.map{|item| {x:item[1],y:item[2],z:20}}.select{ |item| item[:x] != nil }
    @all_dates += @transactions_data.map{|item| item[:x]}
    @all_dates = @all_dates.uniq.sort
    end
  end

  def user_and_disposition_summary
    search_params = params[:search]
    if search_params
      sql = build_user_and_date_sql(search_params)
      @disposition_summary = Report.disposition_summary(sql[:date], sql[:user])
      @user_summary = Report.user_summary(sql[:date], sql[:user])
      @action_origin_summary = Report.action_origin_summary(sql[:date], sql[:user])
    else
      @disposition_summary = []
      @user_summary = []
      @action_origin_summary = []
    end
  end

  def user_assignment_distribution
    @user_assignment_distribution =  Report.user_assignment_distribution
  end

  def twelve_week_trailing
    @results = []
    users_collect = User.includes(:employer)
    @users = users_collect.select{ |user| user.employer == current_user.employer }
    @users.each do |user|
      user_results = []

      result_hash = get_distinct_twelve_week_account_data(user.id)

      non_zero = result_hash.select{ |date, val| val > 0 }.count
      if non_zero > 0
        user_total = result_hash.inject(0) { |total, (k, v)| total + v }
        user_average = user_total / non_zero
        user_results << user.email
        result_hash.each do |date, value|
          user_results << value
        end
        user_results << user_total
        user_results << user_average
        @results << user_results
      end
    end

    ### The get_distinct_twelve_week_account_data method also calculates this now, so the code below is redundant
    ### and group_by_week is a little quirky. Might consider a refactor of this section soon.

    #Repeat, but for actions instead of accounts
    @results_actions = []
    @users.each do |user|
      user_results = []
      result_hash = user.account_actions.select(:id,:created_at).distinct.group_by_week(:created_at, last: 12).count
      non_zero = result_hash.select{ |date, val| val > 0 }.count
      if non_zero > 0
        user_total = result_hash.inject(0) { |total, (k, v)| total + v }
        user_average = user_total / non_zero
        user_results << user.email
        result_hash.each do |date, value|
          user_results << value
        end
        user_results << user_total
        user_results << user_average
        @results_actions << user_results
      end
    end

    @json_results = @results.map {|result| {:user => result[0].split("@")[0] || 0, :twelve => result[1] || 0, :eleven => result[2] || 0, :ten => result[3] || 0, :nine => result[4] || 0, :eight => result[5] || 0, :seven => result[6] || 0, :six => result[7] || 0, :five => result[8] || 0, :four => result[9] || 0, :three => result[10] || 0, :last_week => result[11] || 0, :this_week => result[12] || 0, :total => result[13] || 0, :average => result[14] || 0,}}
    @bar_results = @results.map {|result| result[1..-3]}
    @graph_labels = @results.map {|result| result[0].split("@")[0]}

    @json_results_actions = @results_actions.map {|result| {:user => result[0].split("@")[0] || 0, :twelve => result[1] || 0, :eleven => result[2] || 0, :ten => result[3] || 0, :nine => result[4] || 0, :eight => result[5] || 0, :seven => result[6] || 0, :six => result[7] || 0, :five => result[8] || 0, :four => result[9] || 0, :three => result[10] || 0, :last_week => result[11] || 0, :this_week => result[12] || 0, :total => result[13] || 0, :average => result[14] || 0,}}
    @bar_results_actions = @results_actions.map {|result| result[1..-3]}

    respond_to do |format|
        format.html { render layout: "priority" }
    end
  end

  private

  def get_distinct_twelve_week_account_data(user_id)
    end_of_today = (DateTime.parse(Date.today.to_s)+1+5.hours)
    nearest_sunday = (DateTime.parse(Date.today.to_s)-DateTime.now.wday+5.hours)

    sundays = []
    12.times do |i|
      sundays[i] = nearest_sunday-(i*7)
    end

    user_actions = AccountAction.where("user_id=#{user_id} AND created_at > '#{sundays[11].strftime("%Y-%m-%d %H:%M:%S")}' AND created_at < '#{end_of_today.strftime("%Y-%m-%d %H:%M:%S")}'")

    actions_by_week = []
    actions_by_week[0] = user_actions.select{ |a| a.created_at > sundays[0] && a.created_at < end_of_today }
    11.times do |i|
      actions_by_week[i+1] = user_actions.select{ |a| a.created_at > sundays[i+1] && a.created_at < sundays[i] }
    end

    distinct_account_ids_by_week = {}
    12.times do |i|
      distinct_account_ids_by_week[sundays[11-i]] = actions_by_week[11-i].pluck(:account_id).uniq.count
    end

    return distinct_account_ids_by_week

  end

  def build_user_and_date_sql_with_b(search_params)
    date_condition = ""
    user_condition = ""
    nested_date_condition = ""
    nested_user_condition = ""
    created_at = "DATE(CONVERT_TZ(aa.created_at,\'+00:00\',\'#{Time.zone.now.formatted_offset}\'))"
    if search_params[:created_at_gteq].present? && search_params[:created_at_lteq].present?
      greater_than = Time.parse(search_params[:created_at_gteq]).to_s
      less_than = (Time.parse(search_params[:created_at_lteq])).to_s
      date_condition += " AND " + created_at + " >= '" + greater_than + "' AND " + created_at + " <= '" + less_than + "'"
      nested_date_condition += " WHERE " + created_at + " >= '" + greater_than + "' AND " + created_at + " <= '" + less_than + "'"
    elsif search_params[:created_at_gteq].present?
      greater_than = Time.parse(search_params[:created_at_gteq]).to_s
      date_condition += " AND " + created_at + " >= '" + greater_than + "'"
      nested_date_condition += " WHERE " + created_at + " >= '" + greater_than + "'"
    elsif search_params[:created_at_lteq].present?
      less_than = Time.parse(search_params[:created_at_lteq]).to_s
      date_condition += " AND " + created_at + " <= '" + less_than + "'"
      nested_date_condition += " WHERE " + created_at + " <= '" + less_than + "'"
    end
    if search_params[:user_id_in].reject(&:empty?).present?
      users = search_params[:user_id_in].reject(&:empty?)
      if date_condition.present?
        user_condition += " AND aa.user_id IN ("
        nested_user_condition += " AND aa.user_id IN ("
      else
        user_condition += " AND aa.user_id IN ("
        nested_user_condition += " WHERE aa.user_id IN ("
      end
      users.each do |id|
          user_condition += id + ", "
          nested_user_condition += id + ", "
      end
      user_condition.slice!(-2, 2)
      user_condition += ") "
      nested_user_condition.slice!(-2, 2)
      nested_user_condition += ") "
    end
    sql = {}
    sql[:date_condition] = date_condition
    sql[:user_condition] = user_condition
    sql[:nested_date_condition] = nested_date_condition
    sql[:nested_user_condition] = nested_user_condition
    sql
  end

  def build_user_and_date_sql(search_params)
    date_sql = ""
    user_sql = ""
    if search_params[:created_at_gteq].present? && search_params[:created_at_lteq].present?
      offset = Time.zone_offset(Time.current.zone)/3600
      greater_than = (Time.parse(search_params[:created_at_gteq]) - offset.hours).to_s
      less_than = (Time.parse(search_params[:created_at_lteq]) - offset.hours + 24.hours).to_s
      date_sql += ' WHERE aa.created_at >= "' + greater_than + '" AND aa.created_at <= "' + less_than + '"'
    end
    if search_params[:user_id_in].reject(&:empty?).present?
      users = search_params[:user_id_in].reject(&:empty?)
      if date_sql.present?
        user_sql += " AND aa.user_id IN ("
      else
        user_sql += " WHERE aa.user_id IN ("
      end
      users.each do |id|
          user_sql += id + ", "
      end
      user_sql.slice!(-2, 2)
      user_sql += ") "
    end
    sql = {}
    sql[:date] = date_sql
    sql[:user] = user_sql
    sql
  end

end
