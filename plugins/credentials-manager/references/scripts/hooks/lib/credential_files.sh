#!/usr/bin/env bash
# credential_files.sh
#
# credentials-manager の PreToolUse フック（preempt_credentials_check.sh）が使う、認証情報系ファイルの判定。
# ファイル系ツールのパス・シェルのコマンド中のトークン・Grep / Glob のパターンで共通に使う。
# source して使う（単体では実行しない）。回帰テストから関数を直接呼べるよう、フック本体から分けている。

# 認証情報系ファイルの判定。$1（パス、またはワイルドカードを含むパターン）が該当すれば、
# 通知の理由文を CF_REASON に入れる（該当しなければ空）。
# ファイル系ツールのパス・シェルのコマンド中のトークン・Grep / Glob のパターンで共通に使う。
# サブシェルを起動しないよう、結果は変数で返す（シェルのトークンごとに呼ぶため）
credential_file_reason() {
  CF_REASON=""
  local path="$1"
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
  # ワイルドカード（.env* / id_rsa* 等）は除いた形で名前を判定する
  local plain="${basename//\*/}"
  plain="${plain//\?/}"

  # .env / .env.* の判定 (example/sample/template/dist/test/spec は除外)
  if [[ "$plain" == ".env" ]]; then
    CF_REASON="環境変数定義ファイル ($basename) を操作"
    return 0
  fi
  if [[ "$plain" == .env.* ]]; then
    case "$plain" in
      .env.example|.env.sample|.env.template|.env.dist|.env.test|.env.spec) ;;
      *)
        CF_REASON="環境変数定義ファイル ($basename) を操作"
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
      CF_REASON="認証情報を含む可能性が高いファイル ($basename) を操作"
      return 0
      ;;
  esac

  # 拡張子 (秘密鍵 / 証明書)。拡張子の前に 1 文字以上あるものに限る
  # （シェルのコマンドでは、jq のフィルタ '.key' のような語幹の無い語が頻出するため）
  case "$basename" in
    ?*.pem|?*.key|?*.p12|?*.pfx|?*.jks|?*.keystore|?*.crt|?*.cer|?*.der|?*.asc|?*.gpg)
      CF_REASON="秘密鍵 / 証明書らしい拡張子のファイル ($basename) を操作"
      return 0
      ;;
  esac

  # 特殊ディレクトリ配下（ディレクトリそのものを含む。Grep の path やシェルの ls ~/.ssh 等）
  [[ "$lower" =~ (^|/)\.(aws|docker|kube|ssh|gnupg)(/|$) ]] || return 0
  if [[ "$lower" =~ (^|/)\.aws(/(credentials|config)(\.|$)|/?$) ]]; then
    CF_REASON="AWS 認証情報ファイル (~/.aws/...) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.docker(/config\.json($|\.)|/?$) ]]; then
    CF_REASON="Docker 認証ファイル (~/.docker/config.json) を操作"
    return 0
  fi
  if [[ "$lower" =~ (^|/)\.kube(/config($|\.)|/?$) ]]; then
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
CRED_FILE_HINT='(\.env|credential|secret|npmrc|netrc|pgpass|dockercfg|id_(rsa|dsa|ecdsa|ed25519|xmss)|serviceaccountkey|service-account|kubeconfig|\.(pem|key|p12|pfx|jks|keystore|crt|cer|der|asc|gpg)|\.aws|\.docker|\.kube|\.ssh|\.gnupg)'
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
    credential_file_reason "$tok"
    [[ -n "$CF_REASON" ]] && break
  done
  [[ -n "$CF_REASON" ]]
}
