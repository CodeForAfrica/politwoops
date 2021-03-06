class Admin::PoliticiansController < Admin::AdminController

  def admin_list
    @politicians = Politician.all
    respond_to do |format|
      format.html { render }
    end
  end

  def admin_user
    begin
      @politician = Politician.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @politician = Politician.where(:user_name => params[:id]).first
      if @politician.nil?
        raise('not found')
      end
    end

    @parties = Party.all
    @offices = Office.all
    @account_types = AccountType.all
    @related = @politician.get_related_politicians().sort_by(&:user_name)

    @unmoderated = DeletedTweet.where(reviewed: false, politician_id: @politician).length

    respond_to do |format|
      format.html { render }
    end
  end

  def new_user
    @parties = Party.all
    @offices = Office.all
    @account_types = AccountType.all

    respond_to do |format|
      format.html { render }
    end
  end

  def get_twitter_id
    t = $twitter.user(params[:screen_name])
    @twitter_id = t.id
    respond_to do |format|
        format.json { render }
    end
  end

  def save_user
    if params[:user_name].to_s == ''
      flash[:error] = "You must specify a twitter username."
      return redirect_to :back
    elsif params[:twitter_id].to_s == ''
      flash[:error] = "Could not find the numeric twitter ID for twitter user #{params[:user_name]}"
      return redirect_to :back
    end

    if params[:id] == '0' then
      existing = Politician.where(user_name: params[:user_name])
      if existing.count == 0
        #it's a new add
        pol = Politician.create(twitter_id: params[:twitter_id],
                                user_name: params[:user_name])
      else
        flash[:error] = "We already track @#{params[:user_name]}"
        pol = nil
      end
    else
      pol = Politician.find(params[:id]) || raise("not found")
      pol.user_name = params[:user_name]
    end

    if not pol.nil?
      pol.party = Party.where(id: params[:party_id]).first
      pol.status = params[:status]
      if params[:account_type_id] == '0' then
        pol.account_type = nil
      else
        pol.account_type = AccountType.where(id: params[:account_type_id]).first
      end
      if params[:office_id] == '0' then
        pol.office = nil
      else
        pol.office = Office.where(id: params[:office_id]).first
      end

      pol.update(politician_params)

      pol.save!
      pol.reset_avatar
    end

    if params[:unapprove_all] and params[:unapprove_all] == 'on' then
        unmod = DeletedTweet.where(reviewed: false, politician_id: pol)
        unmod.each do |utweet|
            utweet.approved = 0
            utweet.review_message = "Bulk unapproved in admin"
            utweet.reviewed = 1
            utweet.reviewed_at = Time.now
            utweet.save()

        end
    end

    if params[:related] then
      requested_names = Set.new(params[:related].split(',')
                                                .map(&:strip)
                                                .reject{ |name| name == '' })
      existing_names = Set.new(pol.get_related_politicians.map(&:user_name))
      pol.remove_related_politicians (existing_names - requested_names)
      pol.add_related_politicians (requested_names - existing_names)
    end

    redirect_to :back
  end

  private

  def politician_params
    params.permit(:user_name, :twitter_id, :party_id, :status, :profile_image_url, :state, :account_type_id, :office_id, :first_name, :middle_name, :last_name, :suffix, :avatar_file_name, :avatar_content_type, :avatar_file_size, :avatar_updated_at, :gender, :bioguide_id, :opencivicdata_id)
  end

end
