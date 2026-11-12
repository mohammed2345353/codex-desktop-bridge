# Codex Desktop Bridge

مهارة وأدوات PowerShell لتنسيق شغل Windows داخل Codex وتقليل طلبات الموافقة المتكررة.

**الإصدار 0.1.0 تجريبي.** المشروع يختار بين الأدوات المتوفرة حسب المهمة. Desktop Commander وأداة التحكم بالشاشة تحتاج اتصالاً وإعداداً مستقلاً؛ وجود المهارة وحده لا يوفّرها.

## التشغيل

المتطلبات: Windows وPowerShell 5.1 أو 7 وCodex CLI مثبت ومسجل الدخول. راجع السكربتات قبل تشغيلها. لا تحتاج تشغيل كمسؤول ولا تغيير Execution Policy من أجل المشروع؛ إذا سياسة جهازك تمنع السكربتات، اتبع إعدادات جهازك المعتمدة.

نزّل المشروع باستخدام Git:

```powershell
git clone https://github.com/mohammed2345353/codex-desktop-bridge.git
Set-Location codex-desktop-bridge
```

من مجلد المشروع، اختَر مجلد عمل موجوداً:

```powershell
.\scripts\Test-BridgeEnvironment.ps1 -Workspace 'C:\Projects\MyProject'
.\scripts\Initialize-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Standard -WhatIf
.\scripts\Initialize-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Standard
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject'
```

الإعداد يضيف المهارة داخل `.agents/skills/codex-desktop-bridge` ويحفظ اختيار وضع التشغيل في `.bridge/settings.json`. أضف `.bridge/` إلى تجاهل Git لأنه يحتوي مساراً محلياً. إعدادات الموافقة العامة تبقى كما هي. إذا نسخة المهارة الموجودة مختلفة، يتوقف السكربت حتى تراجعها.

داخل Codex استخدم `$codex-desktop-bridge` مع المهمة المطلوبة. إعداد مجلد العمل لا يعني تثبيت المهارة في حساب ChatGPT أو كل محادثاته.

## أوضاع الموافقة

| الوضع | النتيجة |
| --- | --- |
| Standard | ينفّذ ضمن الصلاحيات الحالية ويعرض الموافقات المطلوبة |
| Review | يرسل الطلبات المؤهلة للمراجعة التلقائية؛ ممكن تنرفض |
| Quiet | يعمل بدون طلب توسيع الصلاحيات؛ العملية الممنوعة ترجع فشلاً |

```powershell
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Review -DryRun
.\scripts\Start-Bridge.ps1 -Workspace 'C:\Projects\MyProject' -Mode Quiet
```

`DryRun` يعرض معاملات التشغيل بدون بدء جلسة نموذج. هذه الأوضاع تخص جلسة CLI الجديدة. صلاحيات المؤسسة وأدوات MCP والجهاز تبقى نافذة. المراجعة التلقائية قد تستهلك استخداماً إضافياً. وضع workspace-write يحد الكتابة، ولا يعني حصر كل القراءة داخل المجلد. لا يوجد تشغيل بصلاحيات كاملة أو خدمة خلفية.

## الموافقة بالكيبورد

بعد ظهور طلب الموافقة في نافذة Codex النشطة، استخدم الأزرار المعروضة بالطلب. هذا الإصدار لا يثبت اختصاراً عاماً ولا يرسل Enter إلى ChatGPT. مخطط التطوير يتضمن اختصاراً مرتبطاً بطلب معلّق محدد عبر App Server، مع عرض العملية والموافقة عليها مرة واحدة فقط.

## الربط والاختبارات

تفاصيل ربط خادم MCP مثبت مسبقاً موجودة في [الدليل الإنكليزي](README.md). الربط اختياري ويغيّر تسجيل MCP للمستخدم عند تشغيله صراحةً. اتصال Remote Desktop Commander يتم من مزوّده، والتحكم بالشاشة يعتمد على الأداة المتوفرة في الجلسة.

```powershell
.\tests\Run-Tests.ps1
```

الاختبارات تتحقق من الإعداد والمحافظة على الملفات ومعاملات التشغيل باستخدام CLI تجريبي. الاتصال الحقيقي بالكمبيوتر وسلوك النموذج يحتاجان تجربة مستقلة.

إعداد محمد السراي. ترخيص MIT. مشروع مجتمعي مستقل.
