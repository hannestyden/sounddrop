require 'soundcloud'

class DropsController < ApplicationController

  def index
    @drops = Drop.all
  end

  def new
    if session[:access_token_hash].nil?
      render :login_redirect
    else
      client = Soundcloud.new(:access_token => session[:access_token_hash]["access_token"])
      @current_user = client.get('/me')
      @current_user_tracks = client.get('/me/tracks')
      @drop = Drop.new
      @places = Place.all
    end
  end

  def create
    url = params["sc_url"]
    sc_url_regex = /^https?:\/\/(www\.)?soundcloud\.com\/.+\/.+$/i

    @drop = Drop.new(drop_params)

    if !params[:drop][:sc_track].present? and url =~ sc_url_regex
      client = Soundcloud.new({
        :client_id => ENV['SOUNDCLOUD_CLIENT_ID']
        })
      track = client.get("/resolve?url=#{url}")
      @drop.sc_track = track.id
    end

    if @drop.save
      redirect_to drop_path(@drop.sc_track)
    else
      client = Soundcloud.new(:access_token => session[:access_token_hash]["access_token"])
      @current_user = client.get('/me')
      @current_user_tracks = client.get('/me/tracks')
      @places = Place.all
      render :new
    end
  end

  def show
    client = SoundCloud.new(:client_id => ENV['SOUNDCLOUD_CLIENT_ID'])
    @drop = Drop.find_by_sc_track(params[:id])
    if @drop.nil?
      page_not_found
    else
      display_place(@drop)
      @drop_at_sc = client.get("/tracks/#{@drop.sc_track}")
      display_image(@drop_at_sc)
    end
  end

  def upvote
    @drop = Drop.find(params[:id])
    if session[:liked_drops].nil?
      session[:liked_drops] = []
    end
    unless
      session[:liked_drops].include?(@drop.id)
      @create_votes = @drop.votes.create
      session[:liked_drops] << @drop.id
    end
    @count_votes = @drop.votes.count
    render json: {count_votes: @count_votes, user_session: session[:liked_stories].inspect}
  end

  def playlists
    @drop = Drop.find_by_sc_track(params[:sc_track])
    if @drop.nil?
      page_not_found
    else
      display_place(@drop)
      client = SoundCloud.new(:client_id => ENV['SOUNDCLOUD_CLIENT_ID'])
      @playlist = client.get("/playlists/#{params[:playlist_id]}")
      @current_track_id = params[:sc_track].to_i
      @drop_at_sc = @playlist.tracks.find do |track|
        track[:id] == params[:sc_track].to_i
      end
      @playlist.tracks.each do |track|
        begin
          if track.id == @drop_at_sc.id
            display_image(@drop_at_sc)
          end
        rescue Exception => e
          e.message
        end
      end
    end
  end

  def display_image(drop_at_sc)
      @artwork = drop_at_sc.artwork_url
      if @artwork == nil
        @artwork = drop_at_sc.user.avatar_url
      end
      @artwork.sub! "large", "crop"
  end

  def display_place(drop)
    unless drop.sc_track.nil?
      place = Place.find_by_id(drop.place.id)
      if place != nil
       @place_name = place.name
      end
    end
  end

  private
    def drop_params
      params.require(:drop).permit(:sc_track, :title, :place_id)
    end
end
