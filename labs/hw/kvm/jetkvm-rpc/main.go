// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 FastNetMon (fastnetmon.com)

// jetkvm-rpc runs JSON-RPC calls on a JetKVM: log in, open a WebRTC session
// through /webrtc/signaling/client and send each call on the "rpc" data channel.
// With JETKVM_CAPTURE=<file> it also records JETKVM_CAPTURE_SECS (default 4) of
// the host display as H.264; only H.264 is offered, since the firmware prefers
// H.265 when the peer accepts it.
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/pion/rtcp"
	"github.com/pion/webrtc/v4"
	"github.com/pion/webrtc/v4/pkg/media/h264writer"
)

func die(f string, a ...any) { fmt.Fprintf(os.Stderr, "jetkvm-rpc: "+f+"\n", a...); os.Exit(1) }

func main() {
	if len(os.Args) < 3 {
		die("usage: JETKVM_PASSWORD=... jetkvm-rpc <host> <method> [params-json] [<method> <params-json> ...]")
	}
	host := os.Args[1]
	type call struct{ method, params string }
	var calls []call
	for i := 2; i < len(os.Args); i += 2 {
		c := call{os.Args[i], "{}"}
		if i+1 < len(os.Args) {
			c.params = os.Args[i+1]
		}
		if !json.Valid([]byte(c.params)) {
			die("%s: params are not JSON: %s", c.method, c.params)
		}
		calls = append(calls, c)
	}
	capture := os.Getenv("JETKVM_CAPTURE")
	captureSecs, _ := strconv.Atoi(os.Getenv("JETKVM_CAPTURE_SECS"))
	if captureSecs <= 0 {
		captureSecs = 4
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(30+captureSecs)*time.Second)
	defer cancel()

	jar, _ := cookiejar.New(nil)
	hc := &http.Client{Jar: jar, Timeout: 10 * time.Second}
	base := "http://" + host
	body, _ := json.Marshal(map[string]string{"password": os.Getenv("JETKVM_PASSWORD")})
	resp, err := hc.Post(base+"/auth/login-local", "application/json", strings.NewReader(string(body)))
	if err != nil {
		die("login: %v", err)
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	if resp.StatusCode != 200 {
		die("login: HTTP %d", resp.StatusCode)
	}
	u, _ := url.Parse(base)
	hdr := http.Header{}
	for _, c := range jar.Cookies(u) {
		hdr.Add("Cookie", c.Name+"="+c.Value)
	}
	ws, _, err := websocket.Dial(ctx, "ws://"+host+"/webrtc/signaling/client", &websocket.DialOptions{HTTPHeader: hdr})
	if err != nil {
		die("signaling: %v", err)
	}
	defer ws.Close(websocket.StatusNormalClosure, "")

	me := &webrtc.MediaEngine{}
	for i, fmtp := range []string{
		"level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42001f",
		"level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f",
		"level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=4d001f",
		"level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=640032",
	} {
		c := webrtc.RTPCodecParameters{
			RTPCodecCapability: webrtc.RTPCodecCapability{MimeType: webrtc.MimeTypeH264, ClockRate: 90000, SDPFmtpLine: fmtp},
			PayloadType:        webrtc.PayloadType(102 + 2*i),
		}
		if err := me.RegisterCodec(c, webrtc.RTPCodecTypeVideo); err != nil {
			die("codec: %v", err)
		}
	}
	pc, err := webrtc.NewAPI(webrtc.WithMediaEngine(me)).NewPeerConnection(webrtc.Configuration{})
	if err != nil {
		die("peer: %v", err)
	}
	defer pc.Close()
	dc, err := pc.CreateDataChannel("rpc", nil)
	if err != nil {
		die("datachannel: %v", err)
	}
	result := make(chan json.RawMessage, 1)
	next := 0
	send := func() {
		req, _ := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": next + 1, "method": calls[next].method, "params": json.RawMessage(calls[next].params)})
		dc.SendText(string(req))
	}
	dc.OnOpen(send)
	dc.OnMessage(func(m webrtc.DataChannelMessage) {
		var r struct {
			ID     *int            `json:"id"`
			Result json.RawMessage `json:"result"`
			Error  json.RawMessage `json:"error"`
		}
		if json.Unmarshal(m.Data, &r) != nil || r.ID == nil || *r.ID != next+1 {
			return
		}
		if len(r.Error) > 0 && string(r.Error) != "null" {
			fmt.Fprintf(os.Stderr, "jetkvm-rpc: %s error: %s\n", calls[next].method, r.Error)
			os.Exit(2)
		}
		fmt.Printf("%s: %s\n", calls[next].method, r.Result)
		next++
		if next == len(calls) {
			result <- r.Result
			return
		}
		send()
	})

	captured := make(chan error, 1)
	if capture != "" {
		if _, err = pc.AddTransceiverFromKind(webrtc.RTPCodecTypeVideo, webrtc.RTPTransceiverInit{Direction: webrtc.RTPTransceiverDirectionRecvonly}); err != nil {
			die("video transceiver: %v", err)
		}
		pc.OnTrack(func(t *webrtc.TrackRemote, _ *webrtc.RTPReceiver) {
			w, err := h264writer.New(capture)
			if err != nil {
				captured <- err
				return
			}
			stop := time.Now().Add(time.Duration(captureSecs) * time.Second)
			go func() {
				for time.Now().Before(stop) {
					pc.WriteRTCP([]rtcp.Packet{&rtcp.PictureLossIndication{MediaSSRC: uint32(t.SSRC())}})
					time.Sleep(500 * time.Millisecond)
				}
			}()
			pkts, nal := 0, map[byte]int{}
			for time.Now().Before(stop) {
				pkt, _, err := t.ReadRTP()
				if err != nil {
					break
				}
				pkts++
				if len(pkt.Payload) > 1 {
					nal[pkt.Payload[0]&0x1f]++
				}
				w.WriteRTP(pkt)
			}
			if os.Getenv("JETKVM_DEBUG") != "" {
				fmt.Fprintf(os.Stderr, "capture: codec %s, %d RTP packets, NAL types %v\n", t.Codec().MimeType, pkts, nal)
			}
			captured <- w.Close()
		})
	}

	offer, err := pc.CreateOffer(nil)
	if err != nil {
		die("offer: %v", err)
	}
	gathered := webrtc.GatheringCompletePromise(pc)
	if err = pc.SetLocalDescription(offer); err != nil {
		die("local description: %v", err)
	}
	<-gathered
	ld, _ := json.Marshal(pc.LocalDescription())
	if err = wsjson.Write(ctx, ws, map[string]any{"type": "offer", "data": map[string]string{"sd": base64.StdEncoding.EncodeToString(ld)}}); err != nil {
		die("send offer: %v", err)
	}

	go func() {
		for {
			typ, msg, err := ws.Read(ctx)
			if err != nil {
				return
			}
			if typ != websocket.MessageText {
				continue
			}
			var m struct {
				Type  string          `json:"type"`
				Data  json.RawMessage `json:"data"`
				Error json.RawMessage `json:"error"`
			}
			if json.Unmarshal(msg, &m) != nil {
				continue
			}
			switch m.Type {
			case "answer":
				var s string
				json.Unmarshal(m.Data, &s)
				b, err := base64.StdEncoding.DecodeString(s)
				if err != nil {
					die("answer: %v", err)
				}
				var sd webrtc.SessionDescription
				if err = json.Unmarshal(b, &sd); err != nil {
					die("answer: %v", err)
				}
				if err = pc.SetRemoteDescription(sd); err != nil {
					die("remote description: %v", err)
				}
			case "new-ice-candidate":
				var c webrtc.ICECandidateInit
				if json.Unmarshal(m.Data, &c) == nil && c.Candidate != "" {
					pc.AddICECandidate(c)
				}
			default:
				if len(m.Error) > 0 {
					die("signaling error: %s", m.Error)
				}
			}
		}
	}()

	select {
	case <-result:
	case <-ctx.Done():
		die("%s: timed out", calls[next].method)
	}
	if capture != "" {
		select {
		case err := <-captured:
			if err != nil {
				die("capture: %v", err)
			}
		case <-ctx.Done():
			die("capture: no video received")
		}
	}
}
