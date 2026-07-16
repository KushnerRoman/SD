package securitydepot

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDefaultSiteConfigHasSafeDefaults(t *testing.T) {
	cfg := DefaultSiteConfig()

	require.Equal(t, "Security Depot Gateway", cfg.Site.Name)
	require.Equal(t, "hikvision-ds7616ni-16", cfg.Emulation.ProfileID)
	require.True(t, cfg.Fallback.Enabled)
	require.Equal(t, "10s", cfg.Fallback.CheckInterval)
	require.Equal(t, "20s", cfg.Fallback.PrimaryStableFor)
}

func TestSiteConfigValidateRequiresNVRAddressAndChannels(t *testing.T) {
	cfg := DefaultSiteConfig()
	cfg.NVR.Address = ""
	cfg.Channels = nil

	err := cfg.Validate()

	require.Error(t, err)
	require.Contains(t, err.Error(), "nvr address is required")
	require.Contains(t, err.Error(), "at least one enabled channel is required")
}

func TestMergeScanSuggestionsDoesNotOverwriteManualChannelName(t *testing.T) {
	cfg := DefaultSiteConfig()
	cfg.Channels = []ChannelConfig{{
		Enabled:   true,
		Number:    1,
		Name:      "Front Door Manual",
		MainRTSP:  "rtsp://manual/main",
	}}
	scan := ScanResult{
		Channels: []ChannelSuggestion{{
			Number:   1,
			Name:     "Camera 01 From Scan",
			MainRTSP: "rtsp://scan/main",
			SubRTSP:  "rtsp://scan/sub",
		}},
	}

	merged := MergeScanSuggestions(cfg, scan)

	require.Equal(t, "Front Door Manual", merged.Channels[0].Name)
	require.Equal(t, "rtsp://manual/main", merged.Channels[0].MainRTSP)
	require.Equal(t, "rtsp://scan/sub", merged.Channels[0].SubRTSP)
}
