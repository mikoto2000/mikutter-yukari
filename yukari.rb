# -*- coding: utf-8 -*-

require "open3"
require "fileutils"

Plugin.create(:yukari) do
  # デフォルト値設定
  on_boot do |service|
    UserConfig[:yukari_create_command] ||= "~/bin/voiceroidCaller"
    UserConfig[:yukari_read_command] ||= "mpg123"
    UserConfig[:yukari_read_command_args] ||= ""
    UserConfig[:yukari_nhk_news_scrap_command] ||= "~/bin/scrapNhkNews"
    UserConfig[:yukari_working_directory] ||= "~/tmp"
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
  end

  # ゆかりさんに読みあげてもらうコマンド
  # TODO:
  # 外部プログラムのほうでこの辺実装して、
  # プラグインはそれを呼び出すだけとしたほうがスマートかも。
  # 検討して必要なら修正。
  command(:yukari,
    name: 'ゆかりが読む',
    condition: Plugin::Command[:HasOneMessage],
    visible: true,
    role: :timeline) do |opt|
        message = opt.messages.first
        Thread.fork {
            if message.user === 'nhk_news' then
                urls = URI.extract(message.to_s)
                for url in urls do
                    read_string, e, s = Open3.capture3("#{UserConfig[:yukari_nhk_news_scrap_command]} #{url}")
                    read(read_string)
                end
            else
                read_string = message.to_s
                read(read_string)
            end
        }
    end

    # 使用するコマンド組立
    YUKARI_COMMAND = UserConfig[:yukari_create_command]
    READ_COMMAND = "#{UserConfig[:yukari_read_command]} #{UserConfig[:yukari_read_command_args]}"

    # 作業ディレクトリ・一時ファイルパス組立
    WORKING_DIR = UserConfig[:yukari_working_directory]
    TMP_VOICE_NAME = "#{WORKING_DIR}/yukari_#{Time.now.strftime('%Y%m%d%H%M%S')}"
    TMP_VOICE_FILE = "#{TMP_VOICE_NAME}.mp3"

    # メッセージ読み上げ
    READ = "#{READ_COMMAND} #{TMP_VOICE_FILE} 2> /dev/null"

    def read(read_string)
        create = "#{YUKARI_COMMAND} #{TMP_VOICE_NAME} '#{read_string}'"
        Open3.capture3("#{create}")
        Open3.capture3("#{READ}")
        File.delete(File.expand_path("#{TMP_VOICE_FILE}"))
    end
end
