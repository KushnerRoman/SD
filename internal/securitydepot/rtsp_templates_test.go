package securitydepot

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestHikvisionRTSPURLUsesChannelMainAndSubPattern(t *testing.T) {
	nvr := NVRConfig{
		Address:  "192.168.1.64",
		RTSPPort: 554,
		Username: "admin",
		Password: "pass word",
	}

	require.Equal(t,
		"rtsp://admin:pass%20word@192.168.1.64:554/Streaming/Channels/101",
		HikvisionRTSPURL(nvr, 1, StreamMain),
	)
	require.Equal(t,
		"rtsp://admin:pass%20word@192.168.1.64:554/Streaming/Channels/102",
		HikvisionRTSPURL(nvr, 1, StreamSub),
	)
	require.Equal(t,
		"rtsp://admin:pass%20word@192.168.1.64:554/Streaming/Channels/301",
		HikvisionRTSPURL(nvr, 3, StreamMain),
	)
}

func TestRTSPTemplatesForVendorRecommendsHikvision(t *testing.T) {
	templates := RTSPTemplatesForVendor("HIKVISION")

	require.Len(t, templates, 1)
	require.Equal(t, "hikvision-streaming-channels", templates[0].ID)
}
