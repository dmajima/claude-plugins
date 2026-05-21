@{
    # PSScriptAnalyzer 検出ルールセット（B-1: improvement-backlog 由来）
    #
    # 検出契機: 2026-05-18 のセッションで sync-settings/sync.ps1 の
    # String.TrimStart(string) → 実際は char[] 引数受け取り、の API 誤用が
    # 静的解析 6 サイクルを素通りしてデモ実行で初めて発見された事例。
    # PSScriptAnalyzer は AST ベース静的解析で同種の API 齟齬・スタイル違反を
    # 検出する標準ツール。
    #
    # 集計対象重大度: Error → High, Warning → Medium, Information → Low

    IncludeRules = @(
        # 構文・API 誤用検出
        'PSUseDeclaredVarsMoreThanAssignments',
        'PSPossibleIncorrectComparisonWithNull',
        'PSPossibleIncorrectUsageOfAssignmentOperator',
        'PSPossibleIncorrectUsageOfRedirectionOperator',
        'PSAvoidAssignmentToAutomaticVariable',
        'PSAvoidGlobalAliases',
        'PSAvoidGlobalFunctions',
        'PSAvoidGlobalVars',
        'PSReservedCmdletChar',
        'PSReservedParams',
        'PSMissingModuleManifestField',

        # セキュリティ
        'PSAvoidUsingInvokeExpression',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingConvertToSecureStringWithPlainText',
        'PSAvoidUsingUserNameAndPasswordParams',
        'PSAvoidUsingComputerNameHardcoded',
        'PSUsePSCredentialType',
        'PSAvoidShouldContinueWithoutForce',

        # スタイル・移植性
        'PSAvoidUsingCmdletAliases',           # ls / cat 等の alias 使用検出
        'PSAvoidUsingPositionalParameters',
        'PSAvoidUsingWriteHost',               # Write-Output 優先（console-encoding.md 整合）
        'PSAvoidTrailingWhitespace',
        'PSUseShouldProcessForStateChangingFunctions',
        'PSAvoidUsingDeprecatedManifestFields',
        'PSUseUTF8EncodingForHelpFile'
    )

    # 集計対象重大度（Information は Low として通知のみ）
    Severity = @('Error', 'Warning', 'Information')

    # ルール別の重大度オーバーライド（必要に応じて）
    Rules = @{
        PSAvoidUsingWriteHost = @{
            # Write-Host は完全禁止ではなく Warning（PowerShell プロンプト UI で必要なケースあり）
        }
    }
}
