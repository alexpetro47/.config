-- Override bluetooth auto-switch policy to include SoX (voice-dictation)
-- Extends the default application list from 10-default-policy.lua
--
-- Names must match application.name exactly (no globs). For our own scripts,
-- prefer tagging the stream instead of listing names here:
--   PIPEWIRE_PROPS='media.role=Communication'  (pipewire/ALSA-plugin clients)
--   PULSE_PROP='media.role=phone'              (pulse clients)
-- Only fires when the default sink is the BT device; switches back ~5s after
-- the stream closes. Requires hfp_ag in bluez5.roles (50-bluez-config.lua).
bluetooth_policy.policy["media-role.applications"] = {
  -- Default apps
  "Firefox", "Chromium input", "Google Chrome input", "Brave input",
  "Microsoft Edge input", "Vivaldi input", "ZOOM VoiceEngine",
  "Telegram Desktop", "telegram-desktop", "linphone", "Mumble",
  "WEBRTC VoiceEngine", "Skype", "Firefox Developer Edition",
  -- Custom: SoX rec (used by voice-dictation script)
  "SoX",
}
