package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	statsRpc "github.com/forworldm/upf/V2rayStatsProxy/stats"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func Must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func Must2[T any](v T, err error) T {
	Must(err)
	return v
}

func ScanLine(r *bufio.Scanner) string {
	if !r.Scan() {
		Must(r.Err())
		os.Exit(0)
	}
	return r.Text()
}

type AppArgs struct {
	ServerAddr string `json:"serverAddr"`
}

type Request struct {
	Name string          `json:"name"`
	Id   int64           `json:"id"`
	Args json.RawMessage `json:"args"`
}

type StatsArgs struct {
	Pattern string `json:"pattern"`
	Reset   bool   `json:"reset"`
}

type Response struct {
	Id    int64       `json:"id"`
	Value interface{} `json:"value"`
}

func main() {
	reader := bufio.NewScanner(os.Stdin)
	writer := bufio.NewWriter(os.Stdout)
	defer writer.Flush()

	var appArgs AppArgs
	Must(json.Unmarshal([]byte(ScanLine(reader)), &appArgs))

	conn := Must2(grpc.NewClient(appArgs.ServerAddr, grpc.WithTransportCredentials(insecure.NewCredentials())))
	defer conn.Close()

	client := statsRpc.NewStatsServiceClient(conn)
	for {
		var req Request
		Must(json.Unmarshal([]byte(ScanLine(reader)), &req))
		var res interface{}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		switch req.Name {
		case "stats":
			var arg StatsArgs
			Must(json.Unmarshal(req.Args, &arg))
			res = Must2(client.QueryStats(ctx, &statsRpc.QueryStatsRequest{
				Pattern: arg.Pattern,
				Reset_:  arg.Reset,
			}))
		case "sysStats":
			res = Must2(client.GetSysStats(ctx, &statsRpc.SysStatsRequest{}))
		default:
			os.Exit(1)
		}

		cancel()

		data := Must2(json.Marshal(res))
		resp := Response{
			Id:    req.Id,
			Value: json.RawMessage(data),
		}
		Must2(writer.Write(Must2(json.Marshal(resp))))
		Must2(writer.WriteString("\n"))
		Must(writer.Flush())
	}
}
