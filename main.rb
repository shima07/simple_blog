require 'sqlite3'
require 'sinatra'
require 'sinatra/reloader'
require 'active_record'
require 'securerandom'
require 'sanitize'

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
  result = Article.all

  if result.empty?
    print "not found\n"
  else

  end
  @articles = result

  erb :search
end

post '/search?:key' do
  @title = "検索"
  @key = params[:name]

  result = Article.where("title like ?", "%" + params[:name] + "%").limit(30)

  if result.empty?
    print "not found\n"
  else

  end
  @articles = result

  erb :search
end

# 追加
get '/admin/new' do
  @title = "登録"
  erb :new
end

post '/admin/upload' do
  if params["files"]
    ext = ""
    if params["files"][:type].include? "jpeg"
      ext = "jpg"
    elsif params["files"][:type].include? "png"
      ext = "png"
    else
      return "投稿できる画像はjpgかpngのみです"
    end

    file_name = SecureRandom.hex + "." + ext

    File.open("./public/uploads/img/" + file_name, "wb") do |f|
      f.write params["files"][:tempfile].read
    end
  else
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
    body: params[:body],
    tag: params[:tag],
    thumbnail: file_name,
    update_member: params[:update_member],
  )
  print "test"
  print file_name

  redirect '/admin/new'
end

# 更新
get '/admin/edit' do
  @title = "更新"
  result = Article.all

  if result.empty?
    print "not found\n"
  else

  end
  @articles = result

  erb :edit
end

post '/admin/edit' do
  article = Article.find_by_id(params[:id])

  if article.nil?
    print "not found\n"
    redirect '/admin/edit'
  else
    article.update_attributes(
      title: params[:title],
      body: params[:body],
      tag: params[:tag],
      thumbnail: params[:thumbnail],
      update_member: params[:update_member],
      )
  end
  redirect '/admin/edit'
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
    @title = result.title
    @article = result
    erb :page
  end
end

not_found do
  redirect '/'
end
