package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"
)

type Config struct {
	Addr            string
	Secret          string
	RepoDir         string
	UpdateScript    string
	SyncPanelScript string
	LogFile         string
	Branch          string
}

type PushPayload struct {
	Ref        string `json:"ref"`
	Before     string `json:"before"`
	After      string `json:"after"`
	Repository struct {
		FullName string `json:"full_name"`
		CloneURL string `json:"clone_url"`
	} `json:"repository"`
	HeadCommit struct {
		ID      string `json:"id"`
		Message string `json:"message"`
		Author  struct {
			Name string `json:"name"`
		} `json:"author"`
	} `json:"head_commit"`
}

type ReleasePayload struct {
	Action  string `json:"action"`
	Release struct {
		TagName string `json:"tag_name"`
		Name    string `json:"name"`
	} `json:"release"`
	Repository struct {
		FullName string `json:"full_name"`
	} `json:"repository"`
}

type Deployer struct {
	cfg          Config
	mu           sync.Mutex
	running      bool
	panelMu      sync.Mutex
	panelRunning bool
	logWriter    io.Writer
}

func NewDeployer(cfg Config) *Deployer {
	var writer io.Writer = os.Stdout
	if cfg.LogFile != "" {
		f, err := os.OpenFile(cfg.LogFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			log.Printf("[WARN] Failed to open log file %s: %v, logging to stdout", cfg.LogFile, err)
		} else {
			writer = io.MultiWriter(os.Stdout, f)
		}
	}
	return &Deployer{
		cfg:       cfg,
		logWriter: writer,
	}
}

func (d *Deployer) log(format string, v ...interface{}) {
	msg := fmt.Sprintf("[%s] ", time.Now().Format("2006-01-02 15:04:05")) + fmt.Sprintf(format, v...) + "\n"
	d.logWriter.Write([]byte(msg))
}

func (d *Deployer) verifySignature(body []byte, signature string) bool {
	if d.cfg.Secret == "" {
		return true
	}
	if !strings.HasPrefix(signature, "sha256=") {
		return false
	}
	expectedMAC := signature[7:]
	mac := hmac.New(sha256.New, []byte(d.cfg.Secret))
	mac.Write(body)
	actualMAC := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(actualMAC), []byte(expectedMAC))
}

func (d *Deployer) runDeploy(commitID, commitMsg, author string) {
	d.mu.Lock()
	if d.running {
		d.log("[WARN] Deploy already in progress, skipping duplicate trigger for commit %s", commitID)
		d.mu.Unlock()
		return
	}
	d.running = true
	d.mu.Unlock()

	defer func() {
		d.mu.Lock()
		d.running = false
		d.mu.Unlock()
	}()

	d.log("[INFO] ================= Starting OneinStack Deployment =================")
	d.log("[INFO] Triggered by commit: %s (%s) by %s", commitID, commitMsg, author)

	// Step 1: Git Pull
	d.log("[INFO] Updating git repository at %s ...", d.cfg.RepoDir)
	pullCmd := exec.Command("git", "pull", "origin", "main")
	pullCmd.Dir = d.cfg.RepoDir
	pullOut, err := pullCmd.CombinedOutput()
	if err != nil {
		d.log("[ERROR] git pull failed: %v\nOutput: %s", err, string(pullOut))
		return
	}
	d.log("[INFO] git pull success:\n%s", strings.TrimSpace(string(pullOut)))

	// Step 2: Run update.sh oneinstack
	if d.cfg.UpdateScript != "" {
		d.log("[INFO] Running update script: %s oneinstack ...", d.cfg.UpdateScript)
		updateCmd := exec.Command(d.cfg.UpdateScript, "oneinstack")
		updateCmd.Dir = "/root/git/repo"
		updateOut, err := updateCmd.CombinedOutput()
		if err != nil {
			d.log("[ERROR] update script failed: %v\nOutput: %s", err, string(updateOut))
			return
		}
		d.log("[INFO] update script success:\n%s", strings.TrimSpace(string(updateOut)))
	}

	d.log("[INFO] ================= OneinStack Deployment Finished Successfully =================")
}

func (d *Deployer) runSyncPanel(tag string) {
	d.panelMu.Lock()
	if d.panelRunning {
		d.log("[WARN] Panel sync already in progress, skipping duplicate trigger for tag: %s", tag)
		d.panelMu.Unlock()
		return
	}
	d.panelRunning = true
	d.panelMu.Unlock()

	defer func() {
		d.panelMu.Lock()
		d.panelRunning = false
		d.panelMu.Unlock()
	}()

	d.log("[INFO] ================= Starting Panel Synchronization =================")
	d.log("[INFO] Target release tag: %s", tag)

	syncScript := d.cfg.SyncPanelScript
	if syncScript == "" {
		syncScript = "/root/git/repo/sync_panel.sh"
	}

	var args []string
	if tag != "" {
		args = append(args, tag)
	}

	cmd := exec.Command(syncScript, args...)
	cmd.Dir = "/root/git/repo"
	out, err := cmd.CombinedOutput()
	if err != nil {
		d.log("[ERROR] Panel sync failed: %v\nOutput: %s", err, string(out))
		return
	}
	d.log("[INFO] Panel sync output:\n%s", strings.TrimSpace(string(out)))
	d.log("[INFO] ================= Panel Synchronization Finished Successfully =================")
}

func (d *Deployer) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if strings.HasSuffix(r.URL.Path, "/healthz") {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("OK\n"))
		return
	}

	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	sig := r.Header.Get("X-Hub-Signature-256")
	if d.cfg.Secret != "" && !d.verifySignature(body, sig) {
		d.log("[WARN] Unauthorized webhook attempt: invalid signature")
		http.Error(w, "Invalid signature", http.StatusUnauthorized)
		return
	}

	// Support direct manual endpoint: /api/webhook/sync-panel
	if strings.HasSuffix(r.URL.Path, "/sync-panel") {
		tag := r.URL.Query().Get("tag")
		d.log("[INFO] Manual sync-panel triggered (tag: %s)", tag)
		go d.runSyncPanel(tag)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(fmt.Sprintf("Panel sync triggered for tag %s\n", tag)))
		return
	}

	event := r.Header.Get("X-GitHub-Event")
	if event == "" {
		event = r.Header.Get("X-Gitee-Event")
	}

	if event == "ping" {
		d.log("[INFO] Received ping event from GitHub")
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"pong"}`))
		return
	}

	// Handle GitHub Release Event (from Oneinstack-Panel)
	if event == "release" {
		var payload ReleasePayload
		if err := json.Unmarshal(body, &payload); err != nil {
			d.log("[ERROR] JSON unmarshal error for release event: %v", err)
			http.Error(w, "Bad JSON payload", http.StatusBadRequest)
			return
		}

		tag := payload.Release.TagName
		repo := payload.Repository.FullName
		action := payload.Action

		d.log("[INFO] Received release event: action=%s repo=%s tag=%s", action, repo, tag)

		// Trigger sync when published or created
		if action == "published" || action == "created" || action == "released" {
			go d.runSyncPanel(tag)
			w.WriteHeader(http.StatusOK)
			w.Write([]byte(fmt.Sprintf("Panel sync triggered for %s release %s\n", repo, tag)))
			return
		}

		w.Write([]byte(fmt.Sprintf("Ignored release action: %s\n", action)))
		return
	}

	// Handle Git Push Event (default for OneinStack repo)
	if event == "push" {
		var payload PushPayload
		if err := json.Unmarshal(body, &payload); err != nil {
			d.log("[ERROR] JSON unmarshal error: %v", err)
			http.Error(w, "Bad JSON payload", http.StatusBadRequest)
			return
		}

		if payload.Ref != d.cfg.Branch {
			d.log("[INFO] Push ignored for ref: %s (target branch: %s)", payload.Ref, d.cfg.Branch)
			w.Write([]byte(fmt.Sprintf("Ignored branch: %s\n", payload.Ref)))
			return
		}

		commitID := payload.HeadCommit.ID
		if len(commitID) > 8 {
			commitID = commitID[:8]
		}
		commitMsg := payload.HeadCommit.Message
		author := payload.HeadCommit.Author.Name

		d.log("[INFO] Valid push event received on %s! Dispatching deploy job...", payload.Ref)
		go d.runDeploy(commitID, commitMsg, author)

		w.WriteHeader(http.StatusOK)
		w.Write([]byte(fmt.Sprintf("Deployment triggered for commit %s\n", commitID)))
		return
	}

	d.log("[INFO] Ignored event type: %s", event)
	w.Write([]byte(fmt.Sprintf("Ignored event: %s\n", event)))
}

func main() {
	var cfg Config
	flag.StringVar(&cfg.Addr, "addr", "127.0.0.1:9876", "Listening address")
	flag.StringVar(&cfg.Secret, "secret", "", "GitHub Webhook secret token")
	flag.StringVar(&cfg.RepoDir, "repo-dir", "/root/git/repo/oneinstack", "Target git repository directory")
	flag.StringVar(&cfg.UpdateScript, "update-script", "/root/git/repo/update.sh", "Path to update.sh script")
	flag.StringVar(&cfg.SyncPanelScript, "sync-panel-script", "/root/git/repo/sync_panel.sh", "Path to sync_panel.sh script")
	flag.StringVar(&cfg.LogFile, "log-file", "/var/log/oneinstack-webhook.log", "Log file path")
	flag.StringVar(&cfg.Branch, "branch", "refs/heads/main", "Branch ref to watch")
	flag.Parse()

	if envSecret := os.Getenv("WEBHOOK_SECRET"); envSecret != "" && cfg.Secret == "" {
		cfg.Secret = envSecret
	}

	deployer := NewDeployer(cfg)

	mux := http.NewServeMux()
	mux.Handle("/", deployer)

	server := &http.Server{
		Addr:         cfg.Addr,
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	log.Printf("Starting OneinStack Webhook server on %s ...", cfg.Addr)
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server exited with error: %v", err)
	}
}
