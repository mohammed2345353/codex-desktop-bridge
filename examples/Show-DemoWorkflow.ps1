#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Json','Html')][string]$Format='Html')
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/AI.Common.ps1')
$catalog=Read-AIJson (Join-Path $PSScriptRoot '../catalog/providers.json')
$now=[DateTimeOffset]::UtcNow
# Synthetic fixtures only. Never inspect the device, execute an AI or assert an
# actual account has access. Real example confirmations remain disabled.
$providers=foreach($tool in $catalog.providers){
    $c=$null
    if($tool.id -in @('ollama','adobe-firefly')){
        $isLocal=$tool.id -eq 'ollama'
        $c=[pscustomobject]@{available=$true;access=$(if($isLocal){'local-free'}else{'subscription'});processing=$(if($isLocal){'local'}else{'external'});capabilities=$tool.capabilities;confirmedAt=$now.AddMinutes(-1).ToString('o');validUntil=$now.AddHours(1).ToString('o');incrementalCostUsd=0;remainingTasks=10;note='SIMULATED DEMO ONLY. Not an actual account confirmation.'}
    }
    [pscustomobject]@{id=$tool.id;name=($tool.name+' [DEMO]');advertisedCapabilities=$tool.capabilities;confirmation=$c;detected=$false;source=$tool.source;note=$tool.note}
}
$map=[pscustomobject]@{schemaVersion=1;mode='synthetic-demo';providers=@($providers);notice='Simulated accounts only. No discovery or third-party execution.'}
$request=Read-AIJson (Join-Path $PSScriptRoot 'tasks.json')
$request.title='عرض تجريبي — إعداد ريل تعليمي (حسابات وهمية)'
$request.tasks[0].title='كتابة الفكرة';$request.tasks[0].instruction='اكتب مخططاً مختصراً يشرح خط المعالجة داخل المعالج. سلّم نصاً للمراجعة؛ بدون تنفيذ أو رفع ملفات.'
$request.tasks[1].title='مراجعة النص';$request.tasks[1].instruction='استلم النص المعتمد من المستخدم، وراجع دقة المعلومات ووضوح الشرح. سلّم ملاحظات ونسخة مصححة.'
$request.tasks[2].title='تجهيز الرسم';$request.tasks[2].instruction='استلم النص المصحح واقترح رسماً بسيطاً يوضح المراحل. انتظر إذن المستخدم قبل توليد صور أو استهلاك رصيد.'
$request.tasks[3].title='ترتيب الفيديو';$request.tasks[3].instruction='استلم النص والرسم المعتمدين، واقترح ترتيب المشاهد داخل Adobe. انتظر الموافقة قبل تعديل مشروع الفيديو.'
$plan=New-AIPlan $map $request
if($Format -eq 'Html'){ConvertTo-AIWorkflowHtml $plan}else{$plan|ConvertTo-Json -Depth 20}
