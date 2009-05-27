atom_feed do |feed|
  feed.title("LinuxFr.org : les journaux")
  feed.updated(@diaries.first.try :created_at)

  @diaries.each do |diary|
    feed.entry(diary, :url => polymorphic_url([diary.owner, diary])) do |entry|
      entry.title(diary.title)
      entry.content(diary.body, :type => 'html')
      entry.author do |author|
        author.name(diary.user.name)
      end
    end
  end
end
