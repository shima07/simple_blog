require 'sqlite3'
require 'sinatra'
require 'sinatra/reloader'
require 'active_record'
require 'securerandom'
require 'sanitize'
require 'date'
require 'cgi'

ActiveRecord::Base.establish_connection(
  "adapter" => "sqlite3",
  "database" => "./blog.db"
)

after do
  ActiveRecord::Base.connection.close
end

configure do
  Time.zone = "Tokyo"
  ActiveRecord::Base.default_timezone = :local
end

class Article < ActiveRecord::Base
end

helpers do
  alias_method :h, :escape_html
end

get '/' do
  @title = "ホーム"

  result = Article.all.limit(6).order("id DESC")

  if result.empty?
    print "not found\n"
  else

  end
  @articles = result

  erb :index
end

# 検索
get '/search' do
  @title = "検索"
  @q = params[:q]
  @qn = "q=" + params[:q]
  @qhref = "q=" + params[:q]
  @page = 1
  @sort = params[:sort]
  @error = ""
  @articles = ""
  @resultCount = 0

  tp = params[:page].to_i
  if tp.nil?
  elsif tp <= 0
    @page = 1
  else
    @page = params[:page].to_i
  end

  tq = params[:q]
  ts = params[:sort]

  if tq.empty?
    @error = "queryが設定されていません"
  else
    query = ""
    result = ""

    tqa = tq.split(" ")
    for item in tqa do
      if item.include?("title:")
        if item =~ /title:(.+)$/
          if query.empty?
          else
            query += "and "
          end
          query += "title LIKE '%" + $1 + "%' "
        else
          @error = "パラメータが設定されていません"
        end
      elsif item.include?("tag:")
        if item =~ /tag:(.+)$/
          if query.empty?
          else
            query += "and "
          end
          query += "tag LIKE '%" + $1 + "%' "
        else
          @error = "パラメータが設定されていません"
        end
      elsif item.include?("body:")
        if item =~ /body:(.+)$/
          if query.empty?
          else
            query += "and "
          end
          query += "body LIKE '%" + $1 + "%' "
        else
          @error = "パラメータが設定されていません"
        end
      elsif item.include?("member:")
        if item =~ /member:(.+)$/
          if query.empty?
          else
            query += "and "
          end
          query += "update_member LIKE '%" + $1 + "%' "
        else
          @error = "パラメータが設定されていません"
        end
      elsif item.include?("created:")
      elsif item.include?("updated:")
      else
        #通常の文字列検索は本文検索とする
        if query.empty?
        else
          query += "and "
        end
        query += "body LIKE '%" + item + "%' "
      end
    end

    if query.empty?
      @error = "パラメータが設定されていません"
    else
      # sort
      #   投稿順
      #   新着順
      if params[:sort]=="old"
        query += "order by created_at ASC "
        @qhref += "&sort=" + ts
      else
        query += "order by created_at DESC "
      end

      #件数取得
      resultCount = ActiveRecord::Base.connection.execute("select * from articles WHERE " + query)
      @resultCount = resultCount.length

      # page
      if tp.nil?
        query += "limit 6"
      else
        query += "limit " + ((tp-1) * 6 - 1).to_s + ", 6"
      end

      result = ActiveRecord::Base.connection.execute("select * from articles WHERE " + query)
    end

    if result.empty?
      print "not found\n"
    else
    end
    @articles = result
  end

  erb :search
end

# 投稿
get '/admin/new' do
  @title = "投稿"
  erb :new
end

post '/admin/upload' do
  print "upload\n"
  if params["files"]
    ext = ""
    if params["files"][:type].include? "jpeg"
      ext = "jpg"
    elsif params["files"][:type].include? "png"
      ext = "png"
    else
      return "投稿できる画像はjpgかpngのみです"
    end

    file_name = params["files"][:filename] + "." + ext

    File.open("./public/uploads/img/" + file_name, "wb") do |f|
      f.write params["files"][:tempfile].read
    end
  else
    print "error not found\n"
  end
  redirect '/admin/new'
end

post '/admin/new' do
  if params["thumbnail"]
    ext = ""
    if params["thumbnail"][:type].include? "jpeg"
      ext = "jpg"
    elsif params["thumbnail"][:type].include? "png"
      ext = "png"
    else
      return "投稿できる画像はjpgかpngのみです"
    end

    file_name = SecureRandom.hex + "." + ext

    File.open("./public/uploads/thumbnail/" + file_name, "wb") do |f|
      f.write params["thumbnail"][:tempfile].read
    end
  else
    file_name = "noimage.png"
  end

  Article.create(
    title: params[:title],
    mdbody: params[:editor],
    body: params[:body],
    tag: params[:tag],
    thumbnail: file_name,
    update_member: params[:update_member],
  )

  redirect '/admin/new'
end

# 更新
get %r{/admin/edit/([0-9]*)} do |i|
  result = Article.find_by_id(i)

  if result.nil?
    print "not found\n"
    redirect '/'
  else
    @id = i
    @title = "編集"
    @article = {
      "title" => result.title,
      "mdbody" => result.mdbody,
      "body" => result.body,
      "tag" => result.tag,
      "thumbnail" => result.thumbnail,
      "update_member" => result.update_member
    }

    erb :edit
  end
end

post '/admin/edit' do
  article = Article.find_by_id(params[:id])

  if params["thumbnail"]
    ext = ""
    if params["thumbnail"][:type].include? "jpeg"
      ext = "jpg"
    elsif params["thumbnail"][:type].include? "png"
      ext = "png"
    else
      return "投稿できる画像はjpgかpngのみです"
    end

    file_name = SecureRandom.hex + "." + ext

    File.open("./public/uploads/thumbnail/" + file_name, "wb") do |f|
      f.write params["thumbnail"][:tempfile].read
    end
  else
    file_name = article.thumbnail
  end

  if article.nil?
    print "not found\n"
    redirect '/admin/list'
  else
    article.update_attributes(
      title: params[:title],
      mdbody: params[:editor],
      body: params[:body],
      tag: params[:tag],
      thumbnail: file_name,
      update_member: params[:update_member],
      )
  end
  redirect '/admin/list'
end

# 一覧
get '/admin/list' do
  @title = "一覧"
  result = Article.all.order("id DESC")

  if result.empty?
    print "not found\n"
  else

  end
  @articles = result

  erb :list
end

# 削除
post '/admin/delete' do
  article = Article.find_by_id(params[:id])
  if article.nil?
    print "not found"
  else
    article.delete
  end
end

# 記事ページ
get %r{/article/([0-9]*)} do |i|
  result = Article.find_by_id(i)

  if result.nil?
    print "not found\n"
    redirect '/'
  else
    @article = result
    @title = result.title
    @time = DateTime.parse(result.updated_at).strftime("%Y年%m月%d日%H:%M")
    @tags = result.tag.split(",")
    erb :page
  end
end

not_found do
  redirect '/'
end
