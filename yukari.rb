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
    condition: Plugin::Command[:HasMessage],
    visible: true,
    role: :timeline) do |opt|
        Thread.fork {
            for message in opt.messages do
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
            end
        }
    end

    # 使用するコマンド組立
    YUKARI_COMMAND = UserConfig[:yukari_create_command]
    READ_COMMAND = "#{UserConfig[:yukari_read_command]} #{UserConfig[:yukari_read_command_args]}"

    # 作業ディレクトリ・一時ファイルパス組立
    WORKING_DIR = UserConfig[:yukari_working_directory]


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
