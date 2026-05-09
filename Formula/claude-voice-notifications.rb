class ClaudeVoiceNotifications < Formula
  desc "TTS and sound notifications for Claude Code (Stop + Notification hooks)"
  homepage "https://github.com/elminson/claude-voice-notifications"
  license "MIT"

  # Stable install — update URL + sha256 after each tagged release:
  #   git tag v2.0.0 && git push --tags
  #   curl -L https://github.com/elminson/claude-voice-notifications/archive/refs/tags/v2.0.0.tar.gz | shasum -a 256
  # url "https://github.com/elminson/claude-voice-notifications/archive/refs/tags/v2.0.0.tar.gz"
  # sha256 "REPLACE_WITH_SHA256"

  # HEAD install (always latest main):
  head "https://github.com/elminson/claude-voice-notifications.git", branch: "main"

  depends_on :macos   # notify-done/input use `say` and `afplay` (macOS built-ins)
  # Linux users: install espeak or gTTS manually (see README)

  def install
    # Install scripts and support files into Homebrew's prefix
    (prefix/"scripts").install Dir["scripts/*.sh"]
    (prefix/"skill").install "skill"
    (prefix/"sounds").install "sounds"
    prefix.install "install.sh", "uninstall.sh"

    # Make all shell scripts executable
    Dir["#{prefix}/scripts/*.sh", "#{prefix}/install.sh", "#{prefix}/uninstall.sh"].each do |f|
      chmod 0755, f
    end
  end

  def post_install
    # Patch install.sh so it knows where to find the scripts (Homebrew prefix)
    # The installer copies scripts to ~/.claude/voice-notifications/
    system "#{prefix}/install.sh", "--source-dir=#{prefix}/scripts",
           "--skill-dir=#{prefix}/skill"
  rescue
    # post_install errors are non-fatal; the caveats below guide manual setup
    nil
  end

  def caveats
    <<~EOS
      Scripts installed to: #{prefix}/scripts/
      Support files:        #{prefix}/skill/, #{prefix}/sounds/

      To wire up the Claude Code hooks (copies scripts to ~/.claude/ and
      patches ~/.claude/settings.json), run:

        #{prefix}/install.sh

      To remove hooks and scripts:

        #{prefix}/uninstall.sh

      After installation, use /voice-notification inside Claude Code to
      configure sounds, voices, banners, quiet hours, and more.
    EOS
  end

  test do
    # Smoke-test: scripts should be valid bash and accept --help / empty input
    system "bash", "-n", "#{prefix}/scripts/notify-common.sh"
    system "bash", "-n", "#{prefix}/scripts/notify-done.sh"
    system "bash", "-n", "#{prefix}/scripts/notify-input.sh"
    system "bash", "-n", "#{prefix}/scripts/notify-escalate.sh"
  end
end
