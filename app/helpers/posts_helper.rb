module PostsHelper
  def render_with_hashtags(caption)
    caption.gsub(/[#＃][\w\p{Han}ぁ-ヶｦ-ﾟー]+/) do |word|
      link_to word, "/post/hashtag/#{word.delete("#")}"
    end.html_safe
  end
end
