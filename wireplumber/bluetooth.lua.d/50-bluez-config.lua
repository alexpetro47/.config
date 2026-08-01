bluez_monitor.enabled = true

bluez_monitor.properties = {
  -- A2DP = high-quality stereo playback (48kHz), HFP = bidirectional with mic (16kHz mono).
  -- hfp_ag is required for headset mics: the host registers as Audio Gateway, the
  -- headset is the Hands-Free unit. Without it the card gets no headset-head-unit
  -- profile and autoswitch has nothing to switch to.
  ["bluez5.roles"] = "[ a2dp_sink a2dp_source hfp_hf hfp_ag ]",

  -- Only offer codecs AirPods actually support (no AAC on Ubuntu default PipeWire)
  ["bluez5.codecs"] = "[ sbc sbc_xq ]",

  ["bluez5.hfphsp-backend"] = "native",
  ["bluez5.enable-sbc-xq"] = true,
  ["bluez5.enable-msbc"] = true,
  ["bluez5.enable-hw-volume"] = true,

  ["with-logind"] = true,
}

bluez_monitor.rules = {
  {
    matches = {
      {
        { "device.name", "matches", "bluez_card.*" },
      },
    },
    apply_properties = {
      -- Auto-connect A2DP + HFP on reconnect
      ["bluez5.auto-connect"] = "[ a2dp_sink a2dp_source hfp_hf hfp_ag ]",
      -- Hardware volume control
      ["bluez5.hw-volume"] = "[ a2dp_sink a2dp_source hfp_hf hfp_ag ]",
      -- Default to A2DP high-quality profile
      ["device.profile"] = "a2dp-sink",
    },
  },
  {
    matches = {
      {
        { "node.name", "matches", "bluez_input.*" },
      },
      {
        { "node.name", "matches", "bluez_output.*" },
      },
    },
    apply_properties = {
      -- Don't suspend bluetooth audio (prevents reconnection dropouts)
      ["session.suspend-timeout-seconds"] = 0,
    },
  },
}
