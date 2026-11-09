#!/usr/bin/env bash
# credential_files.sh
#
# credentials-manager の PreToolUse フック（preempt_credentials_check.sh）が使う、認証情報系ファイルの判定。
# ファイル系ツールのパス・シェルのコマンド中のトークン・Grep / Glob のパターンで共通に使う。
# source して使う（単体では実行しない）。回帰テストから関数を直接呼べるよう、フック本体から分けている。

# 認証情報系ファイルの判定。$1（パス、またはワイルドカードを含むパターン）が該当すれば、
# 通知の理由文を CF_REASON に入れる（該当しなければ空）。
# $2 に shell を渡すと、シェルのコマンド中のトークンとして判定する（変数のプロパティや jq のパスを拡張子で判定しない）。
# ファイル系ツールのパス・シェルのコマンド中のトークン・Grep / Glob のパターンで共通に使う。
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
  # （.env. / 末尾に空白の付いた .env / .env::$DATA は .env と同じファイルを指す）。. と .. はそのまま
  basename="${basename%::\$data}"
  if [[ $basename =~ ^(.*[^.\ ])[.\ ]+$ ]]; then
    basename=${BASH_REMATCH[1]}
  fi
  # ワイルドカード（.env* / id_rsa* 等）は除いた形で名前を判定する
  local plain="${basename//\*/}"
  plain="${plain//\?/}"
  # 理由文に入れる名前。48 文字までにし、英数字と . _ - * ? ~ @ + 以外は _ に置き換える
  # （名前は additionalContext にそのまま入るため、名前に書いた文がモデルへの指示として読まれないようにする）
  local shown="${basename:0:48}"
  shown="${shown//[^a-z0-9._*?~@+-]/_}"
  (( ${#basename} > 48 )) && shown+="…"

  # .env / .env.* / .envrc（direnv）の判定 (example/sample/template/dist/test/spec は除外)
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

  # 完全一致 (ファイル名)。シェルのトークンごとに呼ぶため、ループではなく case で判定する
  case "$plain" in
    credentials.json|credentials.yml|credentials.yaml|credential.json|\
    secrets.json|secrets.yml|secrets.yaml|secret.json|\
    .npmrc|.netrc|.pgpass|.git-credentials|.dockercfg|\
    id_rsa|id_dsa|id_ecdsa|id_ed25519|id_xmss|\
    serviceaccountkey.json|service-account.json|application_default_credentials.json|gcloud-credentials.json|\
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

  # 拡張子 (秘密鍵 / 証明書)。拡張子の前に 1 文字以上あるものに限る
  # （シェルのコマンドでは、jq のフィルタ '.key' のような語幹の無い語が頻出するため）。
  # シェルのトークンで、$ か . で始まりパスの区切りを含まないもの（$_.Key・$cfg.pem・jq の .data.key 等）は、
  # 変数のプロパティや jq のパスとみなして拡張子では判定しない
  if [[ $mode != shell || $lower == */* || $lower != [\$.]* ]]; then
    case "$basename" in
      ?*.pem|?*.key|?*.p12|?*.pfx|?*.jks|?*.keystore|?*.crt|?*.cer|?*.der|?*.asc|?*.gpg)
        CF_REASON="秘密鍵 / 証明書らしい拡張子のファイル ($shown) を操作"
        return 0
        ;;
    esac
  fi

  # 特殊ディレクトリ配下（ディレクトリそのものと、配下をワイルドカードだけで指すもの（~/.aws/* / **/.kube/**）を含む。
  # Grep の path やシェルの ls ~/.ssh 等）
  [[ "$lower" =~ (^|/)\.(aws|docker|kube|ssh|gnupg)(/|$) ]] || return 0
  if [[ "$lower" =~ (^|/)\.aws(/(credentials|config)(\.|$)|/?$|/[*?/]+$) ]]; then
    CF_REASON="AWS 認証情報ファイル (~/.aws/...) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.docker(/config\.json($|\.)|/?$|/[*?/]+$) ]]; then
    CF_REASON="Docker 認証ファイル (~/.docker/config.json) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.kube(/config($|\.)|/?$|/[*?/]+$) ]]; then
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
CRED_FILE_HINT='(\.env|credential|secret|npmrc|netrc|pgpass|dockercfg|id_(rsa|dsa|ecdsa|ed25519|xmss)|serviceaccountkey|service-account|kubeconfig|hosts\.ya?ml|\.(pem|key|p12|pfx|jks|keystore|crt|cer|der|asc|gpg)|\.aws|\.docker|\.kube|\.ssh|\.gnupg)'
# トークンの区切り（空白・改行・シェルの区切り・括弧・引用符・= ・カンマ）。IFS として使う
SHELL_SEPS=$' \t\n\r;|&()<>"\'=,`{}[]'
# 同じ区切りを tr に渡す形（[ と ] は tr の記法と衝突するため 8 進数で書く）
SHELL_SEPS_TR=$' \t\n\r;|&()<>"\'=,`{}\\133\\135'
# 判定するトークンの上限（手掛かりの語を含むトークンが大量にあるコマンドで、timeout を超えないようにする）
MAX_FILE_TOKENS=256
# これより長いコマンドは、bash のループではなく tr と grep で手掛かりの語を含むトークンだけを取り出す
# （bash の照合はトークン 1 つあたり数十 µs かかり、トークンの総数に比例して遅くなるため）
SCAN_INLINE_MAX=16384

# シェルのコマンド $1 の中で、認証情報系ファイルを指すトークンを探す。
# 見つかれば理由（credential_file_reason の文言）を CF_REASON に入れて 0 を返す。見つからなければ 1 を返す。
# 分割は IFS による読み取りで行う（置換で区切り文字を空白に変えると、区切り文字の多い大きな入力で二乗の時間がかかる）。
# 手掛かりの語を含むトークンが MAX_FILE_TOKENS 個を超えたら判定を打ち切り、控えめに「多数含む」の理由で 0 を返す（無言で欠落させない）。
# 照合は小文字にした文字列で行う（手掛かりの語は小文字で書いてある。nocasematch は他の照合に影響するため使わない）
cred_scan_command_files() {
  local cmd=$1 tok candidates=0
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
    credential_file_reason "$tok" shell
    [[ -n "$CF_REASON" ]] && break
  done
  [[ -n "$CF_REASON" ]]
}

# 波括弧の展開で作る文字列の上限（展開の途中のものを含む）。パターンごとに認証情報系ファイルの判定を行うため、
# 多すぎると timeout を超える。通常のパターン（**/*.{js,ts,jsx,tsx} 等）は数個〜十数個で収まる
MAX_BRACE_ITEMS=64

# Grep の glob・Glob の pattern の波括弧（**/{.env,*.pem} / *.{pem,key}）を展開した候補を CF_CANDIDATES に入れる。
# 入れ子は内側から展開する。展開で作る文字列が MAX_BRACE_ITEMS 個を超える場合は、展開をやめて CF_BRACE_OVERFLOW を 1 にする。
# 入力は信頼できない文字列のため、bash の展開（eval）は使わない
cred_expand_braces() {
  local re='^(.*)[{]([^{}]*,[^{}]*)[}](.*)$' s alt pre body post i=0
  local -a queue=("$1") alts
  CF_CANDIDATES=()
  CF_BRACE_OVERFLOW=""
  while (( i < ${#queue[@]} )); do
    s=${queue[i]}
    i=$((i + 1))
    if [[ $s =~ $re ]]; then
      pre=${BASH_REMATCH[1]} body=${BASH_REMATCH[2]} post=${BASH_REMATCH[3]}
      # 末尾にカンマを足して読む（{a,} の空の候補を落とさないため）
      IFS=, read -r -a alts <<< "$body,"
      if (( ${#queue[@]} + ${#alts[@]} > MAX_BRACE_ITEMS )); then
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

# Grep / Glob の検索対象 $1（パス、またはワイルドカード・波括弧を含むパターン）を判定し、
# 通知の理由文を CF_REASON に入れる（該当しなければ空）。波括弧は展開した候補ごとに判定する
credential_pattern_reason() {
  local cand
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
    credential_file_reason "$cand"
    [[ -n $CF_REASON ]] && return 0
  done
  return 0
}
