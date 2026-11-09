#!/usr/bin/env bash
# credential_files.sh
#
# credentials-manager の PreToolUse フック（preempt_credentials_check.sh）が使う、認証情報系ファイルの判定。
# ファイル系ツールのパス・シェルのコマンド中のトークン・Grep / Glob のパターンで共通に使う。
# source して使う（単体では実行しない）。回帰テストから関数を直接呼べるよう、フック本体から分けている。
# 通知文に入れる名前の無害化（cred_display_name）は lib/credential_patterns.sh にあるため、先にそちらを読み込む。

# 認証情報系ファイルの判定。$1（パス、またはワイルドカードを含むパターン）が該当すれば、
# 通知の理由文を CF_REASON に入れる（該当しなければ空）。
# $2 はシェルのコマンド中のトークンとして判定するときに渡す: shell（Bash）/ pwsh（PowerShell）。
# シェルでは、jq のパス（.data.key）を、PowerShell ではさらに変数のプロパティ（$_.Key）を拡張子で判定しない。
# サブシェルを起動しないよう、結果は変数で返す（シェルのトークンごとに呼ぶため）
credential_file_reason() {
  CF_REASON=""
  local path="$1" mode="${2:-}"
  [[ -z "$path" ]] && return 0
  # 実在するパスより十分長い文字列は、中身を判定せずに控えめに通知する（下の置換は、区切り文字の多い長い文字列で
  # 入力長の二乗の時間がかかる。黙って除外すると、長いパスで判定を逃れられてしまう）
  if (( ${#path} > 4096 )); then
    CF_REASON="長さが 4 KB を超え、認証情報系ファイルかを判定できないパスを操作"
    return 0
  fi

  local lower="${path//\\/\/}"
  lower="${lower,,}"
  local basename="${lower##*/}"
  # Windows はファイル名の末尾の空白・ピリオドと、既定のデータストリームの指定（::$DATA）を無視する
  # （.env. / 末尾に空白の付いた .env / .env::$DATA は .env と同じファイルを指す）。. と .. はそのまま。
  # 正規表現はファイル名として有り得る 255 文字までに限る（ピリオドの多い長い語で、照合に入力長の二乗以上の時間がかかる）
  basename="${basename%::\$data}"
  if (( ${#basename} <= 255 )) && [[ $basename =~ ^(.*[^.\ ])[.\ ]+$ ]]; then
    basename=${BASH_REMATCH[1]}
  fi
  # 親ディレクトリの名前にも同じ正規化を掛け、正規化したファイル名と組み直す（.aws.\credentials 等。特殊ディレクトリの判定に使う）
  if [[ $lower == */* ]]; then
    local dir=${lower%/*} parent prefix=""
    parent=${dir##*/}
    [[ $dir == */* ]] && prefix=${dir%/*}/
    if (( ${#parent} <= 255 )) && [[ $parent =~ ^(.*[^.\ ])[.\ ]+$ ]]; then
      parent=${BASH_REMATCH[1]}
    fi
    lower="$prefix$parent/$basename"
  else
    lower=$basename
  fi
  # ワイルドカード（.env* / id_rsa* 等）は除いた形で名前を判定する
  local plain="${basename//\*/}"
  plain="${plain//\?/}"
  # 理由文に入れる名前（48 文字まで・記号は _ に置き換える。lib/credential_patterns.sh の cred_display_name）
  cred_display_name "$basename"
  local shown=$CRED_SHOWN

  # .env / .env.* / .envrc（direnv）/ <名前>.env の判定 (example/sample/template/dist/test/spec は除外)
  if [[ "$plain" == ".env" || "$plain" == ".envrc" ]]; then
    CF_REASON="環境変数定義ファイル ($shown) を操作"
    return 0
  fi
  if [[ "$plain" == .env.* ]]; then
    case "$plain" in
      .env.example|.env.sample|.env.template|.env.dist|.env.test|.env.spec) ;;
      *)
        CF_REASON="環境変数定義ファイル ($shown) を操作"
        return 0
        ;;
    esac
  fi
  # prod.env / secrets.env 等。JavaScript の process.env・import.meta.env は環境変数の参照のため除く
  if [[ "$plain" == ?*.env ]]; then
    case "${plain%.env}" in
      *example|*sample|*template|*dist|*test|*spec|process|import.meta) ;;
      *)
        CF_REASON="環境変数定義ファイル ($shown) を操作"
        return 0
        ;;
    esac
  fi

  # 完全一致 (ファイル名)。シェルのトークンごとに呼ぶため、ループではなく case で判定する
  case "$plain" in
    credentials.json|credentials.yml|credentials.yaml|credential.json|credentials.toml|credentials.tfrc.json|credentials.db|\
    secrets.json|secrets.yml|secrets.yaml|secret.json|secrets.toml|\
    .npmrc|.netrc|_netrc|.pgpass|.git-credentials|.dockercfg|.pypirc|.vault-token|\
    id_rsa|id_dsa|id_ecdsa|id_ed25519|id_xmss|\
    serviceaccountkey.json|service-account.json|application_default_credentials.json|gcloud-credentials.json|access_tokens.db|\
    msal_token_cache.json|msal_token_cache.bin|accesstokens.json|\
    kubeconfig)
      CF_REASON="認証情報を含む可能性が高いファイル ($shown) を操作"
      return 0
      ;;
  esac

  # GitHub CLI の認証トークン（~/.config/gh/hosts.yml。Windows では %AppData%\GitHub CLI\hosts.yml。
  # シェルのトークンは空白で分かれるため、CLI\hosts.yml の形も対象にする）
  local gh_dir='(^|/)(gh|github cli|cli)$'
  if [[ ($plain == hosts.yml || $plain == hosts.yaml) && $lower == */* && ${lower%/*} =~ $gh_dir ]]; then
    CF_REASON="GitHub CLI の認証ファイル ($shown) を操作"
    return 0
  fi

  # Terraform の state（リソースの秘密の値を平文で含む）
  case "$basename" in
    ?*.tfstate|?*.tfstate.backup)
      CF_REASON="認証情報を含む可能性が高いファイル ($shown) を操作"
      return 0
      ;;
  esac

  # 拡張子 (秘密鍵 / 証明書)。拡張子の前に 1 文字以上あるものに限る
  # （シェルのコマンドでは、jq のフィルタ '.key' のような語幹の無い語が頻出するため）。
  # シェルのトークンで、パスの区切りを含まず . で始まるもの（jq の .data.key 等）、PowerShell ではさらに $ で始まるもの
  # （$_.Key・$cfg.pem 等の変数のプロパティ）は、拡張子では判定しない（Bash の $name.pem は変数 + 拡張子のファイル名として判定する）
  local skip_ext=""
  if [[ ($mode == shell || $mode == pwsh) && $lower != */* ]]; then
    [[ $lower == .* ]] && skip_ext=1
    [[ $mode == pwsh && $lower == \$* ]] && skip_ext=1
  fi
  if [[ -z $skip_ext ]]; then
    case "$basename" in
      ?*.pem|?*.key|?*.p12|?*.pfx|?*.jks|?*.keystore|?*.crt|?*.cer|?*.der|?*.asc|?*.gpg)
        CF_REASON="秘密鍵 / 証明書らしい拡張子のファイル ($shown) を操作"
        return 0
        ;;
    esac
  fi

  # プロセスの環境変数（Linux の /proc/self/environ 等）
  if [[ "$lower" =~ (^|/)proc/[^/]+/environ$ ]]; then
    CF_REASON="プロセスの環境変数 (/proc/.../environ) を操作"
    return 0
  fi

  # 特殊ディレクトリ配下（ディレクトリそのもの、配下をワイルドカードだけで指すもの（~/.aws/* / **/.kube/**）、
  # 途中にディレクトリやワイルドカードを挟むもの（**/.aws/**/credentials）を含む。Grep の path やシェルの ls ~/.ssh 等）
  [[ "$lower" =~ (^|/)\.(aws|docker|kube|ssh|gnupg)(/|$) ]] || return 0
  if [[ "$lower" =~ (^|/)\.aws((/.*)?/(credentials|config)(\.|$)|/?$|/[*?/]+$) ]]; then
    CF_REASON="AWS 認証情報ファイル (~/.aws/...) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.docker((/.*)?/config\.json($|\.)|/?$|/[*?/]+$) ]]; then
    CF_REASON="Docker 認証ファイル (~/.docker/config.json) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.kube((/.*)?/config($|\.)|/?$|/[*?/]+$) ]]; then
    CF_REASON="Kubernetes 認証ファイル (~/.kube/config) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.ssh(/|$) ]]; then
    CF_REASON="SSH 鍵格納ディレクトリ (~/.ssh/) のファイルを操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.gnupg(/|$) ]]; then
    CF_REASON="GPG 設定ディレクトリ (~/.gnupg/) のファイルを操作"
    return 0
  fi

  return 0
}

# シェルのコマンド中で認証情報系ファイルを指すトークンを探す手掛かり（大文字小文字を区別しない）。
# これを含まないコマンドはトークンに分けずに済ませる
CRED_FILE_HINT='(\.env|credential|secret|npmrc|netrc|pgpass|dockercfg|pypirc|vault-token|id_(rsa|dsa|ecdsa|ed25519|xmss)|serviceaccountkey|service-account|access_tokens|msal_token_cache|accesstokens|kubeconfig|hosts\.ya?ml|tfstate|proc/[^/]*/environ|\.(pem|key|p12|pfx|jks|keystore|crt|cer|der|asc|gpg)|\.aws|\.docker|\.kube|\.ssh|\.gnupg)'
# トークンの区切り（空白・改行・シェルの区切り・括弧・引用符・= ・カンマ・:）。IFS として使う。
# : は git show HEAD:.env・scp host:.env 等を分けるため（C:\... のドライブ名も分かれるが、後ろのパスで判定できる）
SHELL_SEPS=$' \t\n\r;|&()<>"\'=,:`{}[]'
# 同じ区切りを tr に渡す形（[ と ] は tr の記法と衝突するため 8 進数で書く）
SHELL_SEPS_TR=$' \t\n\r;|&()<>"\'=,:`{}\\133\\135'
# 判定するトークンの上限（手掛かりの語を含むトークンが大量にあるコマンドで、timeout を超えないようにする）
MAX_FILE_TOKENS=256
# これより長いコマンドは、bash のループではなく tr と grep で手掛かりの語を含むトークンだけを取り出す
# （bash の照合はトークン 1 つあたり数十 µs かかり、トークンの総数に比例して遅くなるため）
SCAN_INLINE_MAX=16384

# シェルのコマンド $1 の中で、認証情報系ファイルを指すトークンを探す。$2 は shell（Bash。既定）か pwsh（PowerShell）。
# 見つかれば理由（credential_file_reason の文言）を CF_REASON に入れて 0 を返す。見つからなければ 1 を返す。
# 分割は IFS による読み取りで行う（置換で区切り文字を空白に変えると、区切り文字の多い大きな入力で二乗の時間がかかる）。
# 手掛かりの語を含むトークンが MAX_FILE_TOKENS 個を超えたら判定を打ち切り、控えめに「多数含む」の理由で 0 を返す（無言で欠落させない）。
# 照合は小文字にした文字列で行う（手掛かりの語は小文字で書いてある。nocasematch は他の照合に影響するため使わない）
cred_scan_command_files() {
  local cmd=$1 mode=${2:-shell} tok candidates=0
  local -a tokens=()
  CF_REASON=""
  if (( ${#cmd} <= SCAN_INLINE_MAX )); then
    [[ ${cmd,,} =~ $CRED_FILE_HINT ]] || return 1
    IFS="$SHELL_SEPS" read -r -d '' -a tokens <<< "$cmd"
  else
    # 入力はヒアストリングで渡す（printf でパイプに書くと、改行の多い入力では 1 行ずつ書き込まれて遅い）
    mapfile -t tokens < <(LC_ALL=C tr "$SHELL_SEPS_TR" '\n' <<< "$cmd" | LC_ALL=C grep -aiE -m $((MAX_FILE_TOKENS + 1)) -- "$CRED_FILE_HINT" 2>/dev/null)
  fi
  for tok in "${tokens[@]}"; do
    [[ -n "$tok" && ${tok,,} =~ $CRED_FILE_HINT ]] || continue
    candidates=$((candidates + 1))
    if (( candidates > MAX_FILE_TOKENS )); then
      CF_REASON="認証情報系ファイルらしい名前を多数含むコマンドを実行"
      break
    fi
    credential_file_reason "$tok" "$mode"
    [[ -n "$CF_REASON" ]] && break
  done
  [[ -n "$CF_REASON" ]]
}

# 波括弧の展開で作る文字列の上限（元のパターンを除き、展開の途中のものを含む）。パターンごとに認証情報系ファイルの判定を
# 行うため、多すぎると timeout を超える。通常のパターン（**/*.{js,ts,jsx,tsx} 等）は数個〜十数個で収まる
MAX_BRACE_ITEMS=64
# Grep / Glob の 1 つの検索対象で判定する候補（波括弧の展開・空白やカンマでの区切りの後）の上限
MAX_PATTERN_CHECKS=256

# Grep の glob・Glob の pattern の波括弧（**/{.env,*.pem} / *.{pem,key}）を展開した候補を CF_CANDIDATES に入れる。
# 入れ子は内側から展開する。展開で作る文字列が MAX_BRACE_ITEMS 個を超える場合は、展開をやめて CF_BRACE_OVERFLOW を 1 にする。
# 入力は信頼できない文字列のため、bash の展開（eval）は使わない
cred_expand_braces() {
  local re='^(.*)[{]([^{}]*,[^{}]*)[}](.*)$' s alt pre body post rest i=0
  local -a queue=("$1") alts
  CF_CANDIDATES=()
  CF_BRACE_OVERFLOW=""
  while (( i < ${#queue[@]} )); do
    s=${queue[i]}
    i=$((i + 1))
    if [[ $s =~ $re ]]; then
      pre=${BASH_REMATCH[1]} body=${BASH_REMATCH[2]} post=${BASH_REMATCH[3]}
      # カンマで分ける。read は改行で止まり末尾の空の候補（{a,}）も落とすため、パラメータ展開で分ける
      alts=()
      rest="$body,"
      while [[ $rest == *,* ]]; do
        alts+=("${rest%%,*}")
        rest=${rest#*,}
      done
      if (( ${#queue[@]} - 1 + ${#alts[@]} > MAX_BRACE_ITEMS )); then
        CF_BRACE_OVERFLOW=1
        CF_CANDIDATES=()
        return 0
      fi
      for alt in "${alts[@]}"; do
        queue+=("$pre$alt$post")
      done
    else
      CF_CANDIDATES+=("$s")
    fi
  done
}

# 逆向きの照合（Grep / Glob のパターンで、認証情報系ファイルの代表的な名前に一致するか）に使う名前。
# どこにでもある名前（CRED_NEUTRAL_NAMES）にも一致するパターンは広すぎるため、認証情報系ファイルを狙ったものとみなさない
CRED_KNOWN_NAMES=(.env .env.local .envrc prod.env credentials.json credentials.yml credentials.yaml credential.json credentials.toml
  credentials.tfrc.json credentials.db secrets.json secrets.yml secrets.yaml secret.json secrets.toml .npmrc .netrc _netrc .pgpass
  .git-credentials .dockercfg .pypirc .vault-token id_rsa id_dsa id_ecdsa id_ed25519 id_xmss serviceaccountkey.json
  service-account.json application_default_credentials.json gcloud-credentials.json access_tokens.db msal_token_cache.json
  accesstokens.json kubeconfig terraform.tfstate server.pem server.key cert.p12 cert.pfx keystore.jks release.keystore
  server.crt server.cer server.der private.asc private.gpg)
CRED_NEUTRAL_NAMES=(readme.md main.go index.ts app.js style.css notes.txt data.json package.json config.yml settings.yaml
  cargo.toml pyproject.toml app.db makefile .bashrc .eslintrc .gitignore)

# パターンのファイル名 $1（小文字。* ? [..] を含む）が、認証情報系ファイルの代表的な名前に一致し、どこにでもある名前に
# 一致しなければ 0 を返し、一致した名前を CRED_KNOWN_HIT に入れる（.e[n]v・cred*・**/.en? 等。名前を除いた判定では拾えない）。
# 照合の時間を抑えるため、64 文字以下・* が 3 個以下（** は 1 個と数える）のパターンに限り、拡張パターンの記号を含むものは扱わない
cred_glob_known_name() {
  local p=$1 n stars
  CRED_KNOWN_HIT=""
  [[ $p == *[*?[]* ]] || return 1
  (( ${#p} <= 64 )) || return 1
  [[ $p == *[\(\)\|\!]* ]] && return 1
  while [[ $p == *'**'* ]]; do
    p=${p//\*\*/\*}
  done
  stars=${p//[^*]/}
  (( ${#stars} <= 3 )) || return 1
  for n in "${CRED_NEUTRAL_NAMES[@]}"; do
    [[ $n == $p ]] && return 1
  done
  for n in "${CRED_KNOWN_NAMES[@]}"; do
    if [[ $n == $p ]]; then
      CRED_KNOWN_HIT=$n
      return 0
    fi
  done
  return 1
}

# Grep / Glob の検索対象 $1（パス、またはワイルドカード・波括弧を含むパターン）を判定し、
# 通知の理由文を CF_REASON に入れる（該当しなければ空）。波括弧は展開し、空白・改行・カンマで区切った
# 複数のパターンも 1 つずつ判定する。名前で判定できないワイルドカード（.e[n]v・cred* 等）は、代表的な名前と逆向きに照合する
credential_pattern_reason() {
  local cand piece base n=0
  local -a pieces
  CF_REASON=""
  if (( ${#1} > 4096 )); then
    credential_file_reason "$1"
    return 0
  fi
  cred_expand_braces "$1"
  if [[ -n $CF_BRACE_OVERFLOW ]]; then
    CF_REASON="波括弧の候補が多く、認証情報系ファイルかを判定できないパターンを指定"
    return 0
  fi
  for cand in "${CF_CANDIDATES[@]}"; do
    IFS=$' \t\n\r,' read -r -d '' -a pieces <<< "$cand"
    for piece in "${pieces[@]}"; do
      [[ -n $piece ]] || continue
      n=$((n + 1))
      if (( n > MAX_PATTERN_CHECKS )); then
        CF_REASON="候補が多く、認証情報系ファイルかを判定できないパターンを指定"
        return 0
      fi
      credential_file_reason "$piece"
      [[ -n $CF_REASON ]] && return 0
      base=${piece//\\/\/}
      base=${base,,}
      base=${base##*/}
      if cred_glob_known_name "$base"; then
        cred_display_name "$base"
        CF_REASON="認証情報系ファイル（$CRED_KNOWN_HIT 等）に一致しうるパターン ($CRED_SHOWN) を指定"
        return 0
      fi
    done
  done
  return 0
}
