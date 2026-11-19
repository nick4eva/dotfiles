#!/usr/bin/env bash
#
# aerc-mail-setup.sh  (v3)
#
# Builds a local mail stack for aerc:
#
#   IMAP -> mbsync -> ~/Mail/<account>/ -> one shared notmuch DB -> aerc
#                                          msmtp <- outgoing
#
# Two modes:
#
#   new        Add an account you have not configured anywhere yet.
#
#   retrofit   Take an account aerc already has (one created by aerc's own
#              :new-account wizard, talking to IMAP directly) and give it the
#              local stack. Reads the host, port, login and credential command
#              out of the existing block, so it asks you almost nothing, then
#              rewrites that block in place to use the notmuch backend.
#
# Run once per account. Everything it would clobber is backed up to
# <file>.bak-<timestamp>.
#
set -euo pipefail

TS=$(date +%Y%m%d-%H%M%S)
AERC_DIR="$HOME/.config/aerc"
ACCOUNTS="$AERC_DIR/accounts.conf"
MSMTP="$HOME/.config/msmtp/config"

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
info() { printf '   %s\n' "$*"; }
warn() { printf '\033[33m !  %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[31m x  %s\033[0m\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

backup() {
  if [ -e "$1" ]; then
    cp -a "$1" "$1.bak-$TS"
    info "backed up $(basename "$1") -> $(basename "$1").bak-$TS"
  fi
  return 0
}

ask() {
  local prompt="$1" default="${2-}" answer
  if [ -n "$default" ]; then read -rp "$prompt [$default]: " answer
  else read -rp "$prompt: " answer; fi
  printf '%s' "${answer:-$default}"
}

askreq() {  # ask, but keep asking until non-empty
  local out=""
  while [ -z "$out" ]; do
    out=$(ask "$1" "${2-}")
    [ -z "$out" ] && warn "This one is required."
  done
  printf '%s' "$out"
}

yesno() {
  local answer
  read -rp "$1 [y/N]: " answer
  [[ "$answer" =~ ^[Yy] ]]
}

urldecode() { printf '%b' "${1//%/\\x}"; }

# Read one key out of one [account] block in accounts.conf.
block_get() {
  [ -f "$ACCOUNTS" ] || return 0
  awk -v a="[$1]" -v k="$2" '
    $0 == a { f = 1; next }
    /^\[/   { f = 0 }
    f && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, ""); print; exit
    }' "$ACCOUNTS"
}

# Split scheme://[user[:pass]@]host[:port] into globals URL_USER/PASS/HOST/PORT.
parse_mail_url() {
  local url="$1" rest userinfo hostport
  URL_SCHEME="${url%%://*}"
  rest="${url#*://}"
  rest="${rest%%/*}"
  if [[ "$rest" == *@* ]]; then
    userinfo="${rest%@*}"          # last @ splits creds from host
    hostport="${rest##*@}"
  else
    userinfo=""
    hostport="$rest"
  fi
  if [[ "$userinfo" == *:* ]]; then
    URL_USER=$(urldecode "${userinfo%%:*}")
    URL_PASS=$(urldecode "${userinfo#*:}")
  else
    URL_USER=$(urldecode "$userinfo")
    URL_PASS=""
  fi
  URL_HOST="${hostport%%:*}"
  if [[ "$hostport" == *:* ]]; then URL_PORT="${hostport##*:}"; else URL_PORT=""; fi
}

# ---------------------------------------------------------------- dependencies

say "Checking dependencies"

MISSING=()
for tool in mbsync notmuch msmtp aerc; do
  have "$tool" || MISSING+=("$tool")
done

if [ ${#MISSING[@]} -gt 0 ]; then
  warn "Missing: ${MISSING[*]}"
  cat <<'EOF'

mbsync ships in the "isync" package:

  Debian/Ubuntu  sudo apt install isync notmuch msmtp aerc   # + pass or libsecret-tools
  Arch           sudo pacman -S isync notmuch msmtp aerc     # + pass or libsecret
  Fedora         sudo dnf install isync notmuch msmtp aerc   # + pass or libsecret
  macOS          brew install isync notmuch msmtp aerc       # + pass
EOF
  exit 1
fi

MBSYNC_VER=$(mbsync --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)
if [ -n "$MBSYNC_VER" ] && [ "$(printf '%s\n1.4\n' "$MBSYNC_VER" | sort -V | head -1)" != "1.4" ]; then
  die "mbsync $MBSYNC_VER is too old (needs >= 1.4 for the Far/Near keywords)."
fi

if ! aerc -v 2>&1 | grep -q '+notmuch'; then
  warn "This aerc was built WITHOUT notmuch support (no +notmuch in 'aerc -v')."
  warn "The notmuch:// source will not load. Rebuild: make GOFLAGS=-tags=notmuch"
  yesno "Continue anyway?" || exit 1
fi

# The account block uses the 0.22 notmuch syntax (source = notmuch://, no
# maildir-store) and multi-file-strategy, which older aerc ignores: it then
# refuses to move/delete any message stored in more than one folder.
AERC_VER=$(aerc -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
if [ -n "$AERC_VER" ] && [ "$(printf '%s\n0.22.0\n' "$AERC_VER" | sort -V | head -1)" != "0.22.0" ]; then
  warn "aerc $AERC_VER is older than 0.22; the generated account block targets 0.22."
  warn "Install a current aerc first (update-ai-tools builds it)."
  yesno "Continue anyway?" || exit 1
fi

info "ok"

# ------------------------------------------------------- inspect existing setup

NM_CONFIG="$HOME/.notmuch-config"
XDG_NM="${XDG_CONFIG_HOME:-$HOME/.config}/notmuch/default/config"
[ -f "$XDG_NM" ] && NM_CONFIG="$XDG_NM"

EXISTING_ROOT=""
[ -f "$NM_CONFIG" ] && EXISTING_ROOT=$(sed -n 's/^[[:space:]]*path=//p' "$NM_CONFIG" | head -1)

EXISTING_ACCOUNTS=""
[ -f "$ACCOUNTS" ] && EXISTING_ACCOUNTS=$(grep -oE '^\[[A-Za-z0-9_-]+\]' "$ACCOUNTS" 2>/dev/null | tr -d '[]' || true)

MODE=new

if [ -n "$EXISTING_ACCOUNTS" ]; then
  say "Existing aerc accounts"
  for a in $EXISTING_ACCOUNTS; do
    src=$(block_get "$a" source)
    case "$src" in
      notmuch://*) info "$a  (already on notmuch)" ;;
      maildir*)    info "$a  (local maildir, no notmuch)" ;;
      imap*)       info "$a  (direct IMAP — can be retrofitted)" ;;
      *)           info "$a  ($src)" ;;
    esac
  done
  [ -n "$EXISTING_ROOT" ] && info "shared notmuch database at $EXISTING_ROOT"

  say "What do you want to do?"
  echo "   1) add a new account"
  echo "   2) retrofit an existing aerc account onto the local stack"
  [ "$(ask "Choice" "1")" = "2" ] && MODE=retrofit
fi

# ---------------------------------------------------------------------- details

REUSE_CRED=""

if [ "$MODE" = retrofit ]; then
  say "Retrofit an existing account"

  while :; do
    ACCOUNT=$(askreq "Which account?" "$(printf '%s\n' "$EXISTING_ACCOUNTS" | head -1)")
    printf '%s\n' "$EXISTING_ACCOUNTS" | grep -qx "$ACCOUNT" && break
    warn "No [$ACCOUNT] block in $ACCOUNTS."
  done

  SRC=$(block_get "$ACCOUNT" source)
  OUT=$(block_get "$ACCOUNT" outgoing)
  FROM=$(block_get "$ACCOUNT" from)
  SRC_CRED=$(block_get "$ACCOUNT" source-cred-cmd)

  case "$SRC" in
    notmuch://*) die "[$ACCOUNT] is already on the notmuch backend. Nothing to retrofit." ;;
    imap*) ;;
    *) warn "[$ACCOUNT] source is '$SRC', not IMAP. You will be asked for the server details." ;;
  esac

  # --- IMAP side
  if [[ "$SRC" == imap* ]]; then
    parse_mail_url "$SRC"
    IMAP_HOST="$URL_HOST"
    IMAP_PORT="${URL_PORT:-993}"
    USERNAME="$URL_USER"
    EMBEDDED_PASS="$URL_PASS"
    info "imap    $USERNAME @ $IMAP_HOST:$IMAP_PORT"
  else
    IMAP_HOST=$(askreq "IMAP host")
    IMAP_PORT=$(ask "IMAP port" "993")
    USERNAME=$(askreq "IMAP login")
    EMBEDDED_PASS=""
  fi

  # --- identity
  if [ -n "$FROM" ]; then
    EMAIL=$(printf '%s' "$FROM" | grep -oE '[^ <>]+@[^ <>]+' | head -1 || true)
    REALNAME=$(printf '%s' "$FROM" | sed -E 's/[[:space:]]*<[^>]*>//' | sed -E 's/^"|"$//g')
    info "from    $FROM"
  fi
  [ -n "${EMAIL:-}" ]    || EMAIL=$(askreq "Email address" "$USERNAME")
  [ -n "${REALNAME:-}" ] || REALNAME=$(askreq "Your name")

  # --- SMTP side
  if [[ "$OUT" == smtp* ]]; then
    parse_mail_url "$OUT"
    SMTP_HOST="$URL_HOST"
    case "$URL_SCHEME" in
      smtps)          SMTP_PORT="${URL_PORT:-465}" ;;
      smtp+insecure)  SMTP_PORT="${URL_PORT:-25}" ;;
      *)              SMTP_PORT="${URL_PORT:-587}" ;;
    esac
    info "smtp    $SMTP_HOST:$SMTP_PORT"
  else
    if [ -n "$OUT" ]; then
      info "outgoing is '$OUT' (not an SMTP URL), so msmtp needs its own details."
    fi
    SMTP_HOST=$(askreq "SMTP host" "smtp.${EMAIL#*@}")
    SMTP_PORT=$(ask "SMTP port (587 = STARTTLS, 465 = TLS)" "587")
  fi

  # --- credentials already in use?
  if [ -n "$SRC_CRED" ]; then
    info "existing credential command: $SRC_CRED"
    if yesno "Reuse it for mbsync and msmtp?"; then
      REUSE_CRED="$SRC_CRED"
    fi
  elif [ -n "$EMBEDDED_PASS" ]; then
    warn "The password is embedded in the source URL in plaintext."
    info "It will not be copied into the new configs; pick a secret store below."
  fi

  MAILROOT="${EXISTING_ROOT:-$(ask "Maildir root" "$HOME/Mail")}"
  [ -n "$EXISTING_ROOT" ] && info "reusing maildir root $MAILROOT"

else
  say "New account details"

  while :; do
    ACCOUNT=$(askreq "Short name (no spaces; becomes the maildir folder + aerc tab)")
    if ! [[ "$ACCOUNT" =~ ^[A-Za-z0-9_-]+$ ]]; then
      warn "Letters, digits, dash and underscore only."
    elif printf '%s\n' "$EXISTING_ACCOUNTS" | grep -qx "$ACCOUNT"; then
      warn "aerc already has [$ACCOUNT]. Re-run and choose option 2 to retrofit it."
    else
      break
    fi
  done

  REALNAME=$(askreq "Your name (as it appears in From:)")
  EMAIL=$(askreq "Email address")
  USERNAME=$(ask "IMAP/SMTP login" "$EMAIL")
  IMAP_HOST=$(askreq "IMAP host" "imap.${EMAIL#*@}")
  IMAP_PORT=$(ask "IMAP port" "993")
  SMTP_HOST=$(askreq "SMTP host" "smtp.${EMAIL#*@}")
  SMTP_PORT=$(ask "SMTP port (587 = STARTTLS, 465 = TLS)" "587")

  if [ -n "$EXISTING_ROOT" ]; then
    MAILROOT="$EXISTING_ROOT"
    info "Reusing maildir root $MAILROOT (a shared notmuch DB needs one root)"
  else
    MAILROOT=$(ask "Maildir root (every account lives in a subfolder of this)" "$HOME/Mail")
  fi
fi

MAILDIR="$MAILROOT/$ACCOUNT"

# ---------------------------------------------------------------------- secrets

say "Secrets"

if [ -n "$REUSE_CRED" ]; then
  SECRET_BACKEND="existing"
  PASSCMD="$REUSE_CRED"
  STORE_CMD="# already handled by: $REUSE_CRED"
  SECRET_PRESENT=yes
  info "using the command this account already uses"
else
  # mbsync and msmtp both accept any command that prints the password on
  # stdout. Supported backends:
  #   pass         GPG-encrypted files. Works headless and over SSH.
  #   secret-tool  libsecret -> gnome-keyring / KWallet over D-Bus. Needs an
  #                unlocked keyring in a session; awkward on servers.
  PASS_OK=no; SECRET_OK=no
  have pass && PASS_OK=yes
  have secret-tool && SECRET_OK=yes

  pick_backend() {
    local answer
    while :; do
      answer=$(ask "Which backend? (pass / secret-tool / plain)" "$1")
      case "$answer" in
        pass)               printf 'pass';        return ;;
        secret-tool|secret) printf 'secret-tool'; return ;;
        plain|none)         printf 'plain';       return ;;
        *) warn "Answer 'pass', 'secret-tool' or 'plain'." ;;
      esac
    done
  }

  if [ "$PASS_OK" = yes ] && [ "$SECRET_OK" = yes ]; then
    info "Both pass and secret-tool are installed."
    SECRET_BACKEND=$(pick_backend pass)
  elif [ "$PASS_OK" = yes ]; then
    info "Found pass; using it."
    SECRET_BACKEND=pass
  elif [ "$SECRET_OK" = yes ]; then
    info "Found secret-tool; using it."
    SECRET_BACKEND=secret-tool
  else
    warn "Neither pass nor secret-tool is installed."
    cat <<'EOF'

   pass         GPG-encrypted files under ~/.password-store. Works anywhere,
                including headless servers. Setup:
                  install pass gnupg
                  gpg --quick-generate-key "you@example.com"
                  pass init you@example.com

   secret-tool  Stores secrets in gnome-keyring or KWallet via D-Bus. Good on
                a desktop where the keyring unlocks at login. Install:
                  Debian/Ubuntu  libsecret-tools
                  Arch / Fedora  libsecret

EOF
    info "Configs are written for whichever you pick; install it before syncing."
    SECRET_BACKEND=$(pick_backend pass)
  fi

  BACKEND_READY=no
  case "$SECRET_BACKEND" in
    pass)
      PASS_ENTRY=$(ask "pass entry name" "mail/$ACCOUNT")
      PASSCMD="pass show $PASS_ENTRY"
      STORE_CMD="pass insert $PASS_ENTRY"
      [ "$PASS_OK" = yes ] && BACKEND_READY=yes
      ;;
    secret-tool)
      # Store and lookup attributes must match exactly, so both come from here.
      SECRET_ATTRS="service mail account $ACCOUNT"
      PASSCMD="secret-tool lookup $SECRET_ATTRS"
      STORE_CMD="secret-tool store --label='mail: $ACCOUNT' $SECRET_ATTRS"
      [ "$SECRET_OK" = yes ] && BACKEND_READY=yes
      ;;
    plain)
      warn "Using a placeholder. Edit the PassCmd / passwordeval lines by hand."
      PASSCMD="echo CHANGE_ME"
      STORE_CMD="# no secret store; edit ~/.mbsyncrc and $MSMTP"
      ;;
  esac

  SECRET_PRESENT=no
  if [ "$BACKEND_READY" = yes ]; then
    if eval "$PASSCMD" >/dev/null 2>&1; then
      info "secret already stored and readable"
      SECRET_PRESENT=yes
    else
      info "No secret stored for this account yet."
      if yesno "Store it now? ($SECRET_BACKEND prompts you; this script never sees it)"; then
        if eval "$STORE_CMD"; then
          SECRET_PRESENT=yes; info "stored"
        else
          warn "Storing failed. Do it later with: $STORE_CMD"
        fi
      fi
    fi
  fi
fi

# ---------------------------------------------------------------------- confirm

SYNC_EVERY=$(ask "Sync interval for the systemd timer" "5min")

MAKE_DEFAULT=yes
if [ -f "$MSMTP" ] && grep -q '^account default' "$MSMTP" 2>/dev/null; then
  yesno "Make $ACCOUNT the default msmtp account?" || MAKE_DEFAULT=no
fi

echo
say "Summary"
cat <<EOF
   mode         $MODE
   account      $ACCOUNT$([ "$MODE" = retrofit ] && echo "  (block will be rewritten in place)")
   from         $REALNAME <$EMAIL>
   imap         $USERNAME @ $IMAP_HOST:$IMAP_PORT
   smtp         $USERNAME @ $SMTP_HOST:$SMTP_PORT
   maildir      $MAILDIR
   notmuch db   $MAILROOT  (shared)
   queries      scoped to path:$ACCOUNT/**
   secrets      $SECRET_BACKEND -> $PASSCMD
EOF
echo
yesno "Write these configs?" || { echo "Aborted, nothing written."; exit 0; }

mkdir -p "$MAILDIR" "$AERC_DIR" "$(dirname "$MSMTP")" \
         "$HOME/.local/bin" "$HOME/.config/systemd/user"
chmod 700 "$MAILROOT"

CERTFILE=""
for c in /etc/ssl/certs/ca-certificates.crt /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/cert.pem; do
  [ -r "$c" ] && { CERTFILE="$c"; break; }
done

# --------------------------------------------------------------------- mbsyncrc

say "mbsync"
backup "$HOME/.mbsyncrc"

if grep -q "^IMAPAccount $ACCOUNT\$" "$HOME/.mbsyncrc" 2>/dev/null; then
  warn "mbsyncrc already defines '$ACCOUNT'; leaving it alone."
else
  cat >> "$HOME/.mbsyncrc" <<EOF

# ---- $ACCOUNT ---------------------------------------------------------------
IMAPAccount $ACCOUNT
Host $IMAP_HOST
Port $IMAP_PORT
User $USERNAME
PassCmd "$PASSCMD"
TLSType IMAPS
$([ -n "$CERTFILE" ] && echo "CertificateFile $CERTFILE")
PipelineDepth 50

IMAPStore ${ACCOUNT}-remote
Account $ACCOUNT

MaildirStore ${ACCOUNT}-local
Path $MAILDIR/
Inbox $MAILDIR/INBOX
SubFolders Verbatim

Channel $ACCOUNT
Far :${ACCOUNT}-remote:
Near :${ACCOUNT}-local:
# [Gmail]/All Mail is synced on purpose: it holds the only copy of archived
# mail (Gmail archive = drop the Inbox label), so every message has at least
# one local file. notmuch shows each email once however many copies exist.
Patterns * !"[Gmail]/Important"
Create Both
# Folders (Gmail labels) deleted on the server are removed locally too.
# One-way on purpose: a stray local rm never deletes a server folder, and
# mbsync never removes a folder that still holds mail.
Remove Near
Expunge Both
SyncState *
EOF
  chmod 600 "$HOME/.mbsyncrc"
  info "appended channel '$ACCOUNT' (mbsync -a runs every channel)"
fi

# --------------------------------------------------------------- notmuch config

say "notmuch (shared database)"

if [ -f "$NM_CONFIG" ]; then
  backup "$NM_CONFIG"
  DB_ROOT=$(sed -n 's/^[[:space:]]*path=//p' "$NM_CONFIG" | head -1)
  [ "$DB_ROOT" = "$MAILROOT" ] || \
    die "notmuch database.path is $DB_ROOT but this account lives under $MAILROOT. They must match for a shared database."

  if grep -qF "$EMAIL" "$NM_CONFIG"; then
    info "$EMAIL already registered as one of your identities"
  elif grep -q '^other_email=' "$NM_CONFIG"; then
    awk -v e="$EMAIL" '
      /^other_email=/ { l=$0; if (l !~ /;$/) l = l ";"; print l e ";"; next }
      { print }' "$NM_CONFIG" > "$NM_CONFIG.tmp"
    mv "$NM_CONFIG.tmp" "$NM_CONFIG"
    info "appended $EMAIL to other_email"
  else
    awk -v e="$EMAIL" '{ print } /^primary_email=/ { print "other_email=" e ";" }' \
      "$NM_CONFIG" > "$NM_CONFIG.tmp"
    mv "$NM_CONFIG.tmp" "$NM_CONFIG"
    info "added other_email=$EMAIL"
  fi
else
  mkdir -p "$(dirname "$NM_CONFIG")"
  cat > "$NM_CONFIG" <<EOF
[database]
path=$MAILROOT

[user]
name=$REALNAME
primary_email=$EMAIL

[new]
tags=unread;inbox;
ignore=.uidvalidity;.mbsyncstate;.mbsyncstate.new;.mbsyncstate.journal;.mbsyncstate.lock;.DS_Store

[search]
exclude_tags=deleted;spam;

[maildir]
synchronize_flags=true
EOF
  info "created $NM_CONFIG"
fi

# ----------------------------------------------------------------------- msmtp

say "msmtp"
backup "$MSMTP"

TLS_STARTTLS=on
[ "$SMTP_PORT" = "465" ] && TLS_STARTTLS=off

PREV_DEFAULT=""
if [ -f "$MSMTP" ]; then
  PREV_DEFAULT=$(sed -n 's/^account default[[:space:]]*:[[:space:]]*//p' "$MSMTP" | head -1)
  grep -v '^account default' "$MSMTP" > "$MSMTP.tmp" || true
  mv "$MSMTP.tmp" "$MSMTP"
fi

if grep -q "^account $ACCOUNT\$" "$MSMTP" 2>/dev/null; then
  warn "msmtp already has an '$ACCOUNT' account; leaving it alone."
else
  cat >> "$MSMTP" <<EOF

account $ACCOUNT
host $SMTP_HOST
port $SMTP_PORT
from $EMAIL
user $USERNAME
passwordeval "$PASSCMD"
auth on
tls on
tls_starttls $TLS_STARTTLS
$([ -n "$CERTFILE" ] && echo "tls_trust_file $CERTFILE")
logfile ~/.cache/msmtp.log
EOF
fi

if [ "$MAKE_DEFAULT" = yes ] || [ -z "$PREV_DEFAULT" ]; then
  DEFAULT_ACCOUNT="$ACCOUNT"
else
  DEFAULT_ACCOUNT="$PREV_DEFAULT"
fi
printf '\naccount default : %s\n' "$DEFAULT_ACCOUNT" >> "$MSMTP"
chmod 600 "$MSMTP"
info "default account: $DEFAULT_ACCOUNT"

# ------------------------------------------------------------ scoped query maps

# Every line carries path:<account>/** . aerc applies :search and :filter on
# top of the active folder query, so that scope is inherited by every search
# run in this tab. One unscoped line is a hole in the isolation.
#
# Only virtual views go here. With maildir integration on, aerc already lists the
# real maildir folders (INBOX, Sent, Drafts, Trash, ...) next to these queries,
# so an inbox/sent/drafts/trash query would show up as a duplicate folder.
write_query_map() {
  local account="$1" gmail="${2:-no}" map="$AERC_DIR/notmuch-queries-$1"
  backup "$map"
  cat > "$map" <<EOF
# Scoped to the $account account. Keep the path: terms — aerc applies
# :search / :filter on top of the active folder query, so these are what stop
# searches in this tab from returning other accounts' mail.
# Real folders (INBOX, Sent, ...) come from the maildir; don't redefine them here.
unread=tag:unread and path:$account/** and not tag:deleted
flagged=tag:flagged and path:$account/**
last-week=path:$account/** and date:1week..now and not tag:deleted
EOF
  # On Gmail the synced [Gmail]/All Mail folder already is the "all" view.
  [ "$gmail" = yes ] || echo "all=path:$account/** and not tag:deleted" >> "$map"
  info "wrote $(basename "$map")"
}

case "$IMAP_HOST" in
  imap.gmail.com|imap.googlemail.com) IS_GMAIL=yes ;;
  *)                                  IS_GMAIL=no ;;
esac

say "aerc query maps"
write_query_map "$ACCOUNT" "$IS_GMAIL"

for prev in $EXISTING_ACCOUNTS; do
  [ "$prev" = "$ACCOUNT" ] && continue
  map="$AERC_DIR/notmuch-queries-$prev"
  legacy="$AERC_DIR/notmuch-queries"
  if [ ! -f "$map" ] && [ -f "$legacy" ]; then
    warn "Account '$prev' uses the unscoped $legacy"
    if yesno "  Rewrite it as a scoped map for '$prev'?"; then
      write_query_map "$prev"
      tmp=$(mktemp)
      awk -v a="[$prev]" -v m="$AERC_DIR/notmuch-queries-$prev" '
        $0==a {f=1} /^\[/ && $0!=a {f=0}
        f && /^query-map/ { print "query-map     = " m; next }
        { print }' "$ACCOUNTS" > "$tmp"
      mv "$tmp" "$ACCOUNTS"
      info "pointed [$prev] at its scoped map"
    fi
  fi
done

# -------------------------------------------------------------- aerc account

say "aerc account block"
backup "$ACCOUNTS"

# Folder names are relative to maildir-account-path and follow the server's
# layout (SubFolders Verbatim). Gmail keeps its own copy of sent mail, so
# copy-to stays empty there or every message would be stored twice.
case "$IMAP_HOST" in
  imap.gmail.com|imap.googlemail.com)
    COPY_TO=""
    POSTPONE="[Gmail]/Drafts"
    FOLDERS_SORT="INBOX,[Gmail]/Drafts,[Gmail]/Sent Mail,[Gmail]/All Mail,[Gmail]/Starred,[Gmail]/Spam,[Gmail]/Trash"
    ;;
  *)
    COPY_TO="Sent"
    POSTPONE="Drafts"
    FOLDERS_SORT="INBOX,Drafts,Sent,Archive,Junk,Trash"
    ;;
esac

NEWBLOCK=$(mktemp)
{
  echo
  echo "[$ACCOUNT]"
  echo "source        = notmuch://"
  echo "maildir-account-path = $ACCOUNT"
  echo "outgoing      = msmtp --account=$ACCOUNT --read-envelope-from --read-recipients"
  echo "default       = INBOX"
  echo "from          = $REALNAME <$EMAIL>"
  echo "copy-to       = $COPY_TO"
  echo "postpone      = $POSTPONE"
  echo "folders-sort  = $FOLDERS_SORT"
  echo "query-map     = $AERC_DIR/notmuch-queries-$ACCOUNT"
  echo "exclude-tags  = deleted,spam"
  echo "multi-file-strategy = act-dir"
} > "$NEWBLOCK"

if [ "$MODE" = retrofit ]; then
  # Replace the old block where it sits, so the tab keeps its position.
  tmp=$(mktemp)
  awk -v a="[$ACCOUNT]" -v nb="$NEWBLOCK" '
    $0 == a { f = 1; while ((getline l < nb) > 0) print l; close(nb); next }
    /^\[/ && f { f = 0 }
    f { next }
    { print }' "$ACCOUNTS" > "$tmp"
  mv "$tmp" "$ACCOUNTS"
  info "rewrote [$ACCOUNT] in place (old version is in the .bak file)"
else
  cat "$NEWBLOCK" >> "$ACCOUNTS"
  info "appended [$ACCOUNT]; tab order follows block order in $ACCOUNTS"
fi
rm -f "$NEWBLOCK"
chmod 600 "$ACCOUNTS"

# Gmail: show [Gmail]/Drafts, [Gmail]/Sent Mail, [Gmail]/Trash as Drafts,
# Sent, Trash. Display only; the maildir names (and :cf) are unchanged.
case "$IMAP_HOST" in
  imap.gmail.com|imap.googlemail.com)
    AERC_CONF="$AERC_DIR/aerc.conf"
    if grep -qF "[ui:account=$ACCOUNT]" "$AERC_CONF" 2>/dev/null; then
      info "aerc.conf already has [ui:account=$ACCOUNT]; leaving it alone"
    else
      backup "$AERC_CONF"
      cat >> "$AERC_CONF" <<EOF

# Gmail: show [Gmail]/Drafts, [Gmail]/Sent Mail, [Gmail]/Trash as Drafts, Sent, Trash.
# Display only; commands like :cf still take the real folder name.
[ui:account=$ACCOUNT]
dirlist-left={{replace \`^\\[Gmail\\]/(.+?)( Mail)?\$\` \`\$1\` .Folder}}
# Gmail-style conversations
threading-enabled=true
EOF
      info "aerc.conf: [Gmail]/ prefix hidden and threads on in $ACCOUNT"
    fi
    ;;
esac

# ---------------------------------------------- optional unified-search account

ACCOUNT_COUNT=$(grep -cE '^\[[A-Za-z0-9_-]+\]' "$ACCOUNTS" || true)
if [ "${ACCOUNT_COUNT:-0}" -gt 1 ] && ! grep -q '^\[all\]' "$ACCOUNTS"; then
  echo
  info "A shared database also allows one tab that searches everything."
  if yesno "Add an unscoped [all] tab for cross-account search?"; then
    cat > "$AERC_DIR/notmuch-queries-all" <<EOF
# Deliberately unscoped: this tab spans every account in the database.
inbox=tag:inbox and not tag:deleted
unread=tag:unread and not tag:deleted
flagged=tag:flagged
last-week=date:1week..now and not tag:deleted
all=not tag:deleted
EOF
    cat >> "$ACCOUNTS" <<EOF

[all]
source        = notmuch://
outgoing      = msmtp --account=$DEFAULT_ACCOUNT --read-envelope-from --read-recipients
default       = inbox
from          = $REALNAME <$EMAIL>
query-map     = $AERC_DIR/notmuch-queries-all
exclude-tags  = deleted,spam
multi-file-strategy = act-dir
EOF
    info "added [all] — no maildir-account-path, so it sees the whole database"
  fi
fi

# ------------------------------------------------------------- mailsync wrapper

say "sync wrapper + timer"

if [ ! -x "$HOME/.local/bin/mailsync" ]; then
  cat > "$HOME/.local/bin/mailsync" <<'EOF'
#!/bin/sh
# Sync every mbsync channel, reindex, reap anything tagged deleted.
# flock keeps the timer and a manual run from racing each other.
set -eu

LOCK="${XDG_RUNTIME_DIR:-/tmp}/mailsync.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK"
  flock -n 9 || { echo "mailsync already running"; exit 0; }
fi

# mbsync exits 1 when any single mailbox fails (e.g. a Gmail label that is
# listed but cannot be selected) even though the rest synced. Keep going so
# notmuch still indexes what did arrive, and report the failure at the end.
rc=0
mbsync -a || rc=$?
# Not --quiet: its one-line summary (new mail, renames = flag changes) is the
# sync log in journalctl --user -u mailsync.
notmuch new

# The deleted tag is not a deletion: remove the files, drop them from the
# index, then let the second mbsync propagate the expunge upstream.
notmuch search --format=text0 --output=files tag:deleted \
  | xargs -0 --no-run-if-empty rm -f
notmuch new --quiet

mbsync -a || rc=$?
exit "$rc"
EOF
  chmod +x "$HOME/.local/bin/mailsync"
  info "wrote ~/.local/bin/mailsync"
else
  info "mailsync is already in ~/.local/bin (it syncs all accounts with mbsync -a)"
fi

if have systemctl && [ -d /run/systemd/system ]; then
  cat > "$HOME/.config/systemd/user/mailsync.service" <<EOF
[Unit]
Description=Sync mail (mbsync + notmuch)
After=network-online.target

[Service]
Type=oneshot
ExecStart=$HOME/.local/bin/mailsync
Nice=10
EOF
  cat > "$HOME/.config/systemd/user/mailsync.timer" <<EOF
[Unit]
Description=Sync mail every $SYNC_EVERY

[Timer]
# counted from when the timer itself starts (login, restart). OnBootSec and
# OnStartupSec can already be over by then, and OnUnitActiveSec needs one run
# this boot before it schedules anything, so on their own nothing ever fires.
OnActiveSec=1min
OnUnitActiveSec=$SYNC_EVERY
AccuracySec=30s

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  info "one timer covers every account"
else
  warn "No systemd — schedule ~/.local/bin/mailsync via cron or launchd."
fi

# ------------------------------------------------------------------ scope audit

say "Scope audit"
LEAKS=0
for map in "$AERC_DIR"/notmuch-queries-*; do
  [ -f "$map" ] || continue
  base=$(basename "$map")
  [ "$base" = "notmuch-queries-all" ] && continue
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in *path:*) ;; *) warn "$base: unscoped -> $line"; LEAKS=$((LEAKS+1)) ;; esac
  done < "$map"
done
if [ "$LEAKS" -eq 0 ]; then
  info "every per-account query is scoped"
else
  warn "$LEAKS unscoped queries; searches from those folders span accounts."
fi

# ---------------------------------------------------------------- next steps

cat <<EOF

$(say "Done")

$([ "$SECRET_PRESENT" = yes ] \
  && echo "  1. Secret is in place.        ($SECRET_BACKEND)" \
  || echo "  1. Store the password:        $STORE_CMD")
  2. First sync (slow, once):   mbsync -V $ACCOUNT
  3. Index it:                  notmuch new
  4. Start the timer:           systemctl --user enable --now mailsync.timer
  5. Launch aerc.
$([ "$MODE" = retrofit ] && cat <<'NOTE'

Retrofit notes:

  * The first mbsync downloads the whole mailbox. aerc's IMAP cache is not
    reusable, so expect a long first run and a lot of disk.

  * Your old IMAP block is preserved in the accounts.conf .bak file. If
    something looks wrong, copy it back and the account works as before —
    nothing about the retrofit is destructive on the server side.

  * The folder list is your IMAP folder tree (from the maildir) plus a few
    virtual views from the query map (unread, flagged, last-week, all).
    Add views to the query map, but don't reuse a real folder's name.
NOTE
)
$([ "$SECRET_BACKEND" = secret-tool ] && cat <<'NOTE'

secret-tool caveat: the keyring must be unlocked for mbsync to read the
password. A systemd --user timer inherits DBUS_SESSION_BUS_ADDRESS from your
session, so it works while you are logged in graphically, but a sync fired
before login or over plain SSH fails the lookup. Either use pass for those, or
unlock first: eval \$(gnome-keyring-daemon --start --components=secrets)
NOTE
)
Multi-account notes:

  * ':search deploy' in the $ACCOUNT tab only hits path:$ACCOUNT/**, because
    aerc applies notmuch queries on top of the active folder query.

  * ':cf <query>' and ':query' start a NEW top-level query and ignore that
    scope. Add the path term yourself:
        :cf tag:unread and path:$ACCOUNT/**

  * To reorder tabs, move the [blocks] around in $ACCOUNTS.

EOF