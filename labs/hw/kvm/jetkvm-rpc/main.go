// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 FastNetMon (fastnetmon.com)

// jetkvm-rpc runs JSON-RPC calls on a JetKVM: log in, open a WebRTC session
// through /webrtc/signaling/client and send each call on the "rpc" data channel.
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
	"strings"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/pion/webrtc/v4"
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
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
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

	pc, err := webrtc.NewPeerConnection(webrtc.Configuration{})
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
}
