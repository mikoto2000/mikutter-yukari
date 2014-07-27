# -*- coding: utf-8 -*-

require "open3"
require "fileutils"
require "workers"

Plugin.create(:yukari) do
  # 最後に読んだツイートの時間を記憶
  last_read_date = nil
  # スレッドプール
  pool = nil

  on_boot do |service|
    # 設定のデフォルト値設定
    UserConfig[:yukari_create_command] ||= "~/bin/voiceroidCaller"
    UserConfig[:yukari_read_command] ||= "mpg123"
    UserConfig[:yukari_read_command_args] ||= ""
    UserConfig[:yukari_nhk_news_scrap_command] ||= "~/bin/scrapNhkNews"
    UserConfig[:yukari_working_directory] ||= "~/tmp"
    UserConfig[:yukari_is_auto_read] ||= false

    # 受信ツイート読み上げ機能初期化
    last_read_date = Time.now
    pool = Workers::Pool.new(:size => 1)
  end

  # config に設定項目を追加
  settings("ゆかりが読む") do
      settings("基本設定") do
          input '音声作成コマンド', :yukari_create_command
          input '音声再生コマンド', :yukari_read_command
          input '音声再生コマンド引数', :yukari_read_command_args
          input 'nhk_news スクレイピングコマンド', :yukari_nhk_news_scrap_command
          input '作業ディレクトリ', :yukari_working_directory
      end
      settings("自動読み上げ設定") do
          boolean '自動読み上げを有効にする', :yukari_is_auto_read
      end
  end

  # ツイート受信で自動読み上げ
  onupdate do |service, messages|
      # 受信したツイートを巡る
      for message in messages do
          # 起動以前のツイートは無視する
          if message[:created] < last_read_date then
              next
          end

          pool.perform do
              if UserConfig[:yukari_is_auto_read] then
                  readMessage(message)
              end
          end
      end
  end

  # ゆかりさんに読みあげてもらうコマンド
  # TODO:
  # 外部プログラムのほうでこの辺実装して、
  # プラグインはそれを呼び出すだけとしたほうがスマートかも。
  # 検討して必要なら修正。
  command(:yukari,
    name: 'ゆかりが読む',
    condition: Plugin::Command[:HasMessage],
    visible: true,
    role: :timeline) do |opt|
        pool.perform do
            for message in opt.messages do
                readMessage(message)
            end
        end
    end

    # メッセージを読み上げる
    def readMessage(message)
        read_string = getReadString(message)
        read(read_string)
    end

    # メッセージから読み上げる文字列を取得する
    def getReadString(message)
       read_string = nil
       if message.user === 'nhk_news' then
           urls = URI.extract(message.to_s)
           for url in urls do
               read_string, _, _ = Open3.capture3("#{UserConfig[:yukari_nhk_news_scrap_command]} #{url}")
           end
       else
           read_string = message.to_s
       end

       return read_string
    end

    # 使用するコマンド組立
    YUKARI_COMMAND = UserConfig[:yukari_create_command]
    READ_COMMAND = "#{UserConfig[:yukari_read_command]} #{UserConfig[:yukari_read_command_args]}"

    # 作業ディレクトリ・一時ファイルパス組立
    WORKING_DIR = UserConfig[:yukari_working_directory]

    # read_string を読み上げる
    def read(read_string)
        tmp_voice_name = "#{WORKING_DIR}/yukari_#{Time.now.strftime('%Y%m%d%H%M%S')}"
        create = "#{YUKARI_COMMAND} #{tmp_voice_name} '#{read_string}'"
        tmp_voice_file = "#{tmp_voice_name}.mp3"

        # メッセージ読み上げ
        read = "#{READ_COMMAND} #{tmp_voice_file} 2> /dev/null"

        Open3.capture3("#{create}")
        Open3.capture3("#{read}")
        File.delete(File.expand_path("#{tmp_voice_file}"))
    end
end
