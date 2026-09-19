# سياسة خصوصية قُرب — TapVault

آخر تحديث: 2026-09-20.

قُرب تطبيق لقراءة وسوم NFC المتوافقة وإعداد محتوى NDEF وكتابته وتنظيمه على جهازك. لا يتطلب حسابًا، ولا يحتوي إعلانات أو أدوات تتبع أو تحليلات تابعة لجهات أخرى. لا يرسل التطبيق محتوى الوسوم أو معرفاتها أو مكتبتك إلى المطور أو إلى خادم للتطبيق.

## بياناتك على الجهاز

عند اختيار المسح، يستخدم التطبيق NFC لقراءة المعلومات المتاحة من الوسم الذي تقرّبه. تحفظ النتائج فقط عند اختيارك الحفظ. قد تتضمن البيانات نصوصًا وروابط ومعلومات اتصال ومعرف الشريحة وملاحظاتك. لا يطلب التطبيق الوصول إلى جهات اتصال الجهاز أو موقعك؛ بيانات الاتصال والإحداثيات تدخلها بنفسك.

تُخزن المكتبة محليًا مشفرة باستخدام AES-GCM من مكتبة Apple CryptoKit، ويُحفظ المفتاح في Keychain. لا توجد شاشة قفل أو مصادقة حيوية إضافية داخل التطبيق. لا توفر هذه الحماية ضمانًا مطلقًا لمنع الوصول إلى بيانات جهاز مفتوح. لا توجد مزامنة سحابية تلقائية للمكتبة، ويستثني التطبيق مجلد البيانات من النسخ الاحتياطي للنظام.

## ما تختار مشاركته

يمكنك مشاركة سجل أو رمز QR أو ملف نسخة احتياطية باستخدام خدمات النظام. يتيح ذلك للجهة أو الخدمة التي تختارها الوصول إلى المحتوى المرسل؛ السجل النصي وQR غير مشفرين. تُشفّر ملفات النسخ الاحتياطي برمز استعادة مستقل. احتفظ بالرمز بعيدًا عن الملف، فالمطور لا يستطيع استعادة البيانات عند فقدانه.

عند كتابة محتوى على وسم، يصبح هذا المحتوى متاحًا لقارئ الوسم بحسب خصائصه. وعند فتح رابط خارجي أو ملف Apple Wallet، تنطبق ممارسات الموقع أو التطبيق أو جهة إصدار البطاقة. صفحات الدعم وسياسة الخصوصية مستضافة على GitHub، وتخضع الزيارات إليها لسياسة GitHub.

## الحذف والاحتفاظ

يمكنك حذف البطاقات من داخل التطبيق. يستمر وجود أي ملفات مصدّرة أو نسخ شاركتها حتى تحذفها من وجهاتها. حذف التطبيق يحذف بيانات حاويته، وقد يبقى مفتاح Keychain تحت إدارة النظام؛ المفتاح وحده لا يحتوي بطاقاتك. لا يحتفظ المطور بنسخة من مكتبتك، ولا يمكنه استعادتها.

## الدعم والتواصل

للاستفسارات أو طلبات الخصوصية، افتح [طلب دعم في المستودع الرسمي](https://github.com/BANKCIB/tapvault-reader-build/issues/new). الطلبات هناك عامة؛ لا تنشر معرفات بطاقاتك أو محتواها أو مفاتيح الاستعادة أو أي بيانات شخصية حساسة. مشاركة هذه البيانات غير مطلوبة للدعم.

## Privacy summary in English

Qurb stores NFC records locally and does not collect or transmit user data to its developer. No account, advertising, analytics SDK, or tracking is included. The library uses Apple CryptoKit encryption and a device Keychain key. Users choose whether to export records, encrypted backups, QR codes, or write content to physical tags. Those actions disclose the selected content to the chosen recipient or tag reader. External sites, GitHub support pages, and issuer passes have their own privacy practices. Cards can be deleted in the app; exported copies must be removed separately. Public support requests are available through the link above; never include sensitive tag data or recovery keys.
