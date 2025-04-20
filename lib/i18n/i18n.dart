import 'dart:developer';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

BehaviorSubject<Map<String, String?>> currentLocalization =
    BehaviorSubject.seeded(I18n._localizations['en']!);
BehaviorSubject<Locale> localeSubject = BehaviorSubject<Locale>();

class I18n {
  static Stream<Map<String, String?>> get currentLocalizationStream =>
      currentLocalization.stream;

  static Locale get currentLocale => localeSubject.value;
  static void init() {
    final localeCache = AppCache.locale.value;
    if (localeCache == null) {
      localeSubject.add(Locale('en'));
    } else {
      localeSubject.add(Locale(localeCache));
    }
    if (kDebugMode) {
      log('init I18n: $localeCache');
      final loc = _localizations[localeCache]!;
      currentLocalization.add(loc);
    }
    localeSubject.listen((locale) {
      final localizations = _localizations[locale.languageCode]!;
      currentLocalization.add(localizations);
    });
  }

  static const Map<String, Map<String, String?>> _localizations = {
    'en': {
      'generate_image': 'Generate image',
      'dalleGenerator': 'DALL-E 3',
      'deepinfraGenerator': 'DeepInfra',
      'disable_tools_btn': 'Disable tools',
    },
    'ru': {
      'Archive this prompt': 'Архивировать этот промпт',
      'Restore this prompt': 'Восстановить этот промпт',
      'Context menu': 'Контекстное меню',
      'Chat field': 'Поле чата',
      'Add new sub-prompt': 'Добавить новый суб-промпт',
      'Sub-prompts': 'Суб-промпты',
      'Archived prompts': 'Архивированные промпты',
      'Add new prompt': 'Добавить новый промпт',
      'Reset to default template': 'Сбросить на шаблон по умолчанию',
      'Quick prompts': 'Быстрые промпты',
      'Save': 'Сохранить',
      'API Key': 'API ключ',
      'Please enter a path': 'Пожалуйста, введите путь',
      'Select': 'Выбрать',
      'Provider': 'Провайдер',
      'Support images?': 'Поддерживает ли изображения?',
      'Model Name (Important. Case sensetive)':
          'Название модели (Важно. Чувствительно к регистру)',
      'Please enter a name': 'Пожалуйста, введите имя',
      'Custom Name': 'Собственное название',
      'Models List': 'Список моделей',
      'Use voice input': 'Использовать голосовой ввод',
      'Pinned messages': 'Закрепленные сообщения',
      'AI have access to pinned messages':
          'ИИ имеет доступ к закрепленным сообщениям',
      'Are you sure?': 'Вы уверены?',
      'This action cannot be undone.': 'Это действие нельзя отменить.',
      'Cancel': 'Отмена',
      'Accept': 'Принять',
      'Restore': 'Восстановить',
      'Commands': 'Команды',
      'Select all': 'Выбрать все',
      'Delete everything above': 'Удалить все выше',
      'Delete everything below': 'Удалить все ниже',
      'New conversation branch from here': 'Новая ветка разговора отсюда',
      'Copy image': 'Копировать изображение',
      'Save image to file': 'Сохранить изображение в файл',
      'Copy': 'Копировать',
      'Pin message': 'Закрепить сообщение',
      'Choose a hotkey': 'Выберите сочетание клавиш',
      'Press a key combination to set a new hotkey (escape to cancel)':
          'Нажмите сочетание клавиш, чтобы установить новую привязку клавиш (escape для отмены)',
      'Current hotkey:': 'Текущая привязка клавиш:',
      'This hotkey is already in use': 'Эта привязка клавиш уже используется',
      'Hotkeys in use (click for details)':
          'Горячие клавиши в использовании (нажмите для деталей)',
      'Hotkeys in use': 'Горячие клавиши в использовании',
      'No microphone found': 'Микрофон не найден',
      'History enabled': 'История чата включена',
      'History disabled': 'История чата отключена',
      'Type your message here': 'Введите ваше сообщение здесь',
      'Style': 'Стиль',
      'Scroll to bottom on new message':
          'Прокручивать вниз при новом сообщении',
      'disable_tools_btn': 'Отключить инструменты',
      'Tools disabled': 'Инструменты отключены',
      'Images in chat': 'Изображения в чате',
      'generate_image': 'Сгенерировать изображение',
      'Memory updated': 'Память обновлена',
      'Remember this': 'Запомнить это',
      'Shorter': 'Короче',
      'Longer': 'Длинее',
      'Open memory': 'Открыть память',
      'Image generator': 'Генератор изображений',
      'dalleGenerator': 'DALL-E 3',
      'deepinfraGenerator': 'DeepInfra',
      'Delete all chat rooms': 'Удалить все чаты',
      'WELCOME!': 'ДОБРО ПОЖАЛОВАТЬ!',
      'Access Granted': 'Доступ предоставлен',
      'Grant Access': 'Предоставить доступ',
      'Configure your AI': 'Настройте ваш ИИ',
      'We will ask for some permissions to make sure you have the best experience':
          'Мы попросим некоторые разрешения, чтобы обеспечить вам лучший опыт',
      'Configure your AI to work as you want':
          'Настройте ваш ИИ так, как вы хотите',
      'Add your models': 'Добавьте свои модели',
      'Add': 'Добавить',
      'Permissions': 'Разрешения',
      'Granting these permissions ensures all features work seamlessly from the get-go.':
          'Предоставление этих разрешений обеспечивает бесперебойную работу всех функций с самого начала.',
      'Files and Folders': 'Файлы и папки',
      'Allows you to save chats history and temprorarily python files generated by LLM':
          'Позволяет сохранять историю чатов и временные файлы python, созданные LLM',
      'Microphone': 'Микрофон',
      'Allows you to record your voice and send it to LLM':
          'Позволяет записывать ваш голос и отправлять его в LLM',
      'Accessibility': 'Доступность',
      'Allows you to use overlay, resize windows and more.':
          'Позволяет использовать наложение, изменять размер окон и многое другое.',
      'Notifications': 'Уведомления',
      'Allows you to receive notifications from the app.':
          'Позволяет получать уведомления от приложения.',
      'Create new chat (only in chat)': 'Создать новый чат (только в чате)',
      'Escape/Cancel selection (only in chat)':
          'Выход/Отмена выбора (только в чате)',
      'Reset chat (only in chat)': 'Сбросить чат (только в чате)',
      'Copy last message to clipboard (only in chat)':
          'Скопировать последнее сообщение в буфер обмена (только в чате)',
      'Include current chat history in conversation':
          'Включить текущую историю чата в разговор',
      'Search in chat (only when input field is focused)':
          'Поиск в чате (только когда поле ввода в фокусе)',
      'Open/Focus/Hide window': 'Открыть/Сфокусировать/Скрыть окно',
      'Show overlay for selected text':
          'Показать наложение для выбранного текста',
      'Shortcuts': 'Ярлыки',
      'This is your quick shortcuts you can use anytime':
          'Это ваши быстрые ярлыки, которые вы можете использовать в любое время',
      'Continue': 'Продолжить',
      'Edit prompt': 'Редактировать промпт',
      'edit_prompt_dialog_helper': '''Помощники:
\${lang} - Текущий язык
\${clipboardAccess} - если вы хотите включить доступ к буферу обмена для LLM
\${input} - выбранный текст''',
      'Title:': 'Заголовок:',
      'Icon:': 'Иконка:',
      'Generate a 3-5 words title based on this prompt: "{{input}}"':
          'Сгенерируйте заголовок из 3-5 слов на основе этого промпта: "{{input}}"',
      'Prompt:': 'Промпт:',
      'Add data to prompt:': 'Добавить данные к промпту:',
      'User input': 'Ввод пользователя',
      'Current language': 'Текущий язык',
      'Clipboard access': 'Доступ к буферу обмена',
      'Info about user': 'Информация о пользователе',
      'Timestamp': 'Метка времени',
      'System info': 'Информация о системе',
      'Tags (Use ; to separate tags)':
          'Теги (используйте ; для разделения тегов)',
      'Tags': 'Теги',
      'Do not show the main window after the prompt is run. The result will be shown in a push notification.\nUseful when you just want to copy the result to clipboard':
          'Не показывать главное окно после выполнения промпта. Результат будет показан в push-уведомлении.\nПолезно, когда вы просто хотите скопировать результат в буфер обмена',
      'Silent': 'Тихий',
      'If checked, the prompt will include system prompt with each activation':
          'Если отмечено, промпт будет включать сис промпт при каждом активации',
      'Include System Prompt': 'Включить системный промпт',
      'If checked, the prompt will include ALL messages from the conversation with each activation':
          'Если отмечено, промпт будет включать ВСЕ сообщения из разговора при каждом активации',
      'Show in chat field': 'Показать в поле чата',
      'Show in context menu': 'Показать в контекстном меню',
      'Show in home page': 'Показать на главной странице',
      'Show in overlay': 'Показать в наложении',
      'Keybinding:': 'Привязка клавиш:',
      'Set keybinding': 'Установить привязку клавиш',
      'Apply': 'Применить',
      'Add sub-prompt list': 'Добавить список суб-промптов',
      'Close': 'Закрыть',
      'Conversation style': 'Стиль разговора',
      'Conversation length': 'Длина разговора',
      'API token is empty!': 'Токен API пуст!',
      'When you send a message, the app will use the system message along with your prompt. This value may differ from your own calculations because some additional information can be sent with each of your prompts.\nTotal is the total tokens that exists in current chat\nSent is the total tokens that you have sent\nReceived is the total tokens that you have received':
          'Когда вы отправляете сообщение, приложение будет использовать системное сообщение вместе с вашим промптом. Это значение может отличаться от ваших собственных расчетов, так как с кадым вашим промптом может быть отправлена дополнительная информация.\nTotal - это общее количество токенов, существующих в текущем чате\nSent - это общее количество токенов, которые вы отправили\nReceived - это общее количество токенов, которые вы получили',
      'Tokens total:': 'Всего токенов:',
      'sent:': 'отправлено:',
      'received:': 'получено:',
      'Text size': 'Размер текста',
      'Include conversation': 'Включить разговор',
      'Add system message': 'Добавить системное сообщение',
      'Capture screenshot': 'Сделать скриншот',
      'You need to obtain Brave API key to use web search':
          'Вам нужно получить ключ API Brave для использования веб-поиска',
      'Settings->API and URLs': 'Настройки->API и URL',
      'Disable web search': 'Отключить веб-поиск',
      'Enable web search': 'Включить веб-поиск',
      'To prevent token overflows unnecessary cost we propose to limit the conversation length':
          'Чтобы предотвратить переполнение токенов и ненужные расходы, мы предлагаем ограничить длину разговора',
      'Max tokens to include': 'Максимальное количество токенов',
      'Min': 'Мин',
      'Med': 'Сред',
      'Hight': 'Выс',
      'Max': 'Макс',
      'Select items to include in system prompt':
          'Выберите элементы для системного промпта',
      'Knowledge about user': 'Знания о пользователе',
      'City name': 'Название города',
      'Weather': 'Погода',
      'User name': 'Имя пользователя',
      'Current timestamp': 'Текущая метка времени',
      'OS info': 'Информация о ОС',
      'Summarize conversation and populate the knowledge about the user':
          'Суммируйте разговор и заполните знания о пользователе',
      'Use memory about the user': 'Использовать память о пользователе',
      'Auto play messages from ai':
          'Автоматическое воспроизведение сообщений от ИИ',
      'Will ask AI to produce buttons for each response. It will consume additional tokens in order to generate suggestions':
          'Попросит ИИ создать кнопки для каждого ответа. Это потребует дополнительных токенов для генерации предложений',
      'Do you want to enable suggestion helpers?':
          'Хотите включить помощников по предложениям?',
      'Enable': 'Включить',
      'No. Don\'t show again': 'Нет. Больше не показывать',
      'Choose code block': 'Выберите блок кода',
      'Dismiss': 'Закрыть',
      'Use "/" or type your message here':
          'Используйте "/" введите ваше сообщение здесь',
      'Settings': 'Настройки',
      'General': 'Общие',
      'Appearance': 'Внешний вид',
      'Tools': 'Инструменты',
      'User info': 'Информация о пользователе',
      'API and URLs': 'API и URL',
      'On response': 'На ответ',
      'Overlay': 'Наложение',
      'Storage': 'Хранилище',
      'Hotkeys': 'Горячие клавиши',
      'About': 'О приложении',
      'Open the window keybinding': 'Привязка клавиш для открытия окна',
      'Open the window': 'Открыть окно',
      'Take a screenshot keybinding': 'Привязка клавиш для скриншота',
      'Use visual AI': 'Использовать визуальный ИИ',
      '[Not set]': '[Не установлено]',
      'Push-to-talk with screenshot': 'Нажмите для разговора со скриншотом',
      'Push-to-talk': 'Нажмите для разговора',
      'Show all keybindings': 'Показать все привязки клавиш',
      'Application storage location': 'Местоположение хранилища приложения',
      'Delete temp cache? Size:': 'Удалить временный кэш? Размер:',
      'Clear all data': 'Очистить все данные',
      'Overlay settings': 'Настройки наложения',
      'Enable overlay': 'Включить наложение',
      'Show settings icon in overlay': 'Показать значок настроек в наложении',
      'Adaptive': 'Адаптивный',
      'Show suggestions after ai response':
          'Показывать предложения после ответа ИИ',
      'Brave API key (search engine) \$':
          'Ключ API Brave (поисковая система) \$',
      'Text-to-Speech service:': 'Служба преобразования текста в речь:',
      'Global system prompt': 'Глобальная системный промпт',
      'Customizable Global system prompt will be used for all NEW chats. To check the whole system prompt press button below':
          'Глобавльный системный промпт будет использоваться для всех НОВЫХ чатов. Чтобы проверить весь системный промпт, нажмите кнопку ниже',
      'Click here to check the whole system prompt':
          'Нажмите здесь, чтобы посмотреть весь промпт',
      'Use ai to name chat': 'Использовать ИИ для названия чата',
      'Can cause additional charges!': 'Может вызвать дополнительные расходы!',
      'Audio and Microphone': 'Аудио и микрофон',
      'Locale': 'Локаль',
      'Launch at startup': 'Запуск при старте',
      'Prevent close app': 'Предотвратить закрытие приложения',
      'Show app in dock': 'Показать приложение в доке',
      'Hide window title': 'Скрыть заголовок окна',
      'User city': 'Город пользователя',
      'Your name that will be used in the chat':
          'Ваше имя, которое будет использоваться в чате',
      'Your city name that will be used in the chat and to get weather':
          'Название вашего города, которое будет использоваться в чате и для получения погоды',
      'Include knowledge about user': 'Включить знания о пользователе',
      'Open info about User': 'Открыть информацию о пользователе',
      'Include user city name in system prompt':
          'Включить название города пользователя в системный промпт',
      'Include weather in system prompt': 'Включить погоду в системный промпт',
      'Include user name in system prompt':
          'Включить имя пользователя в системный промпт',
      'Include current date and time in system prompt':
          'Включить текущую дату и время в системный промпт',
      'Include system info in system prompt':
          'Включить информацию о системе в системный промпт',
      'Learn about the user after creating new chat \$\$':
          'Узнать о пользователе после создания нового чата \$\$',
      'Function tools \$\$': 'Функциональные инструменты \$\$',
      'Toggle All': 'Переключить все',
      'Auto copy to clipboard': 'Автоматическое копирование в буфер обмена',
      'Auto open url': 'Автоматическое открытие URL',
      'Generate images': 'Генерировать изображения',
      'Additional tools': 'Дополнительные инструменты',
      'Imgur (Used to upload your image to your private Imgur account and get image link)':
          'Imgur (Используется для загрузки вашего изображения в ваш личный аккаунт Imgur и получения ссылки на изображение)',
      'Image Search engines': 'Поисковые системы изображений',
      'Enable annoy mode': 'Включить режим раздражения',
      'Use timer and allow AI to write you. Can cause additional charges!':
          'Использовать таймер и позволить ИИ писать вам. Может вызвать дополнительные расходы!',
      'Accent Color': 'Цвет акцента',
      'Theme mode': 'Режим темы',
      'Light': 'Светлая',
      'Dark': 'Темная',
      'Background': 'Фон',
      'Use aero': 'Использовать Aero',
      'Use acrylic': 'Использовать акрил',
      'Use transparent': 'Использовать прозрачный',
      'Use mica': 'Использовать Mica',
      'Transparency': 'Прозрачность',
      'Set window as frameless': 'Установить окно без рамки',
      'Restart the app to apply changes':
          'Перезапустите приложение, чтобы применить изменения',
      'Message Text size': 'Размер текста сообщения',
      'Basic Message Text Size': 'Базовый размер текста сообщения',
      'Compact Message Text Size': 'Компактный размер текста сообщения',
      'Voice:': 'Голос:',
      'Read sample': 'Прочитать образец',
      'Weather in': 'Погода в',
      'More': 'Больше',
      'Edit': 'Редактировать',
      'Continue writing': 'Продолжи текст',
      'Explain this': 'Объясни это',
      'Summarize this': 'Суммируй это',
      'Check grammar': 'Проверь грамматику',
      'Improve writing': 'Улучши написание',
      'Translate': 'Перевести',
      'Answer with tags': 'Ответить с тегами',
      'Search': 'Поиск',
      'Search...': 'Поиск...',
      'Chat rooms': 'Чат комнаты',
      'Create new chat': 'Создать новый чат',
      'Create folder': 'Создать папку',
      'Move to Folder': 'Переместить в папку',
      'Deleted chats': 'Удаленные чаты',
      'Storage usage': 'Использование хранилища',
      'Refresh from disk': 'Обновить с диска',
      'Add new': 'Добавить',
      'AI will be able to remember things about you':
          'ИИ сможет запоминать вещи о вас',
      'Archive chats after (days)': 'Архивировать чаты после (дней)',
      'Delete chats after (days)': 'Удалить чаты после (дней)',
      'Move up': 'Вверх',
      'Model changed to': 'Модель изменена на',
      'Clear current chat?': 'Очистить текущий чат?',
      'No results found for your query': 'Нет результатов для вашего запроса',
      'Edit chat': 'Редактировать чат',
      'Duplicate chat': 'Дублировать чат',
      'Delete chat': 'Удалить чат',
      'Pin/unpin chat': 'Закрепить/открепить чат',
    },
    'es': {
      'Pin/unpin chat': 'Fijar/desfijar chat',
      'Duplicate chat': 'Duplicar chat',
      'Delete chat': 'Eliminar chat',
      'Edit chat': 'Editar chat',
      'Move to Folder': 'Mover a carpeta',
      'Archive this prompt': 'Archivar este prompt',
      'Restore this prompt': 'Restaurar este prompt',
      'Context menu': 'Menú contextual',
      'Chat field': 'Campo de chat',
      'Add new sub-prompt': 'Agregar nuevo sub-prompt',
      'Sub-prompts': 'Sub-prompts',
      'Archived prompts': 'Prompts archivados',
      'Add new prompt': 'Agregar nuevo prompt',
      'Reset to default template': 'Restablecer a la plantilla predeterminada',
      'Quick prompts': 'Prompts rápidos',
      'Save': 'Guardar',
      'API Key': 'Clave API',
      'Please enter a path': 'Por favor, introduce una ruta',
      'Select': 'Seleccionar',
      'Provider': 'Proveedor',
      'Support images?': '¿Soporte de imágenes?',
      'Model Name (Important. Case sensetive)':
          'Nombre del modelo (Importante. Sensible a mayúsculas y minúsculas)',
      'Please enter a name': 'Por favor, introduce un nombre',
      'Custom Name': 'Nombre personalizado',
      'Models List': 'Lista de Modelos',
      'Use voice input': 'Usar entrada de voz',
      'AI have access to pinned messages':
          'La IA tiene acceso a mensajes fijados',
      'Pinned messages': 'Mensajes fijados',
      'Are you sure?': '¿Estás seguro?',
      'This action cannot be undone.': 'Esta acción no se puede deshacer.',
      'Cancel': 'Cancelar',
      'Accept': 'Aceptar',
      'Restore': 'Restaurar',
      'Select all': 'Seleccionar todo',
      'Delete everything above': 'Eliminar todo lo que está arriba',
      'Delete everything below': 'Eliminar todo lo que está debajo',
      'New conversation branch from here':
          'Nueva rama de conversación desde aquí',
      'Copy image': 'Copiar imagen',
      'Save image to file': 'Guardar imagen en archivo',
      'Commands': 'Comandos',
      'Copy': 'Copiar',
      'Pin message': 'Fijar mensaje',
      'No microphone found': 'No se encontró micrófono',
      'History enabled': 'Historial activado',
      'History disabled': 'Historial desactivado',
      'Type your message here': 'Escribe tu mensaje aquí',
      'Scroll to bottom on new message':
          'Desplazarse al final con un nuevo mensaje',
      'No results found for your query':
          'No se encontraron resultados para su consulta',
      'Clear current chat?': '¿Borrar el chat actual?',
      'disable_tools_btn': 'Deshabilitar herramientas',
      'Tools disabled': 'Herramientas desactivadas',
      'Model changed to': 'Modelo cambiado a',
      'Move up': 'Mover arriba',
      'Images in chat': 'Imágenes en el chat',
      'generate_image': 'Generar imagen',
      'Memory updated': 'Memoria actualizada',
      'Remember this': 'Recuerda esto',
      'Shorter': 'Más corto',
      'Longer': 'Más largo',
      'Open memory': 'Abrir memoria',
      'Image generator': 'Generador de imágenes',
      'dalleGenerator': 'DALL-E 3',
      'deepinfraGenerator': 'DeepInfra',
      'Delete all chat rooms': 'Eliminar todas las salas de chat',
      'Archive chats after (days)': 'Archivar chats después de (días)',
      'Delete chats after (days)': 'Eliminar chats después de (días)',
      'WELCOME!': '¡BIENVENIDO!',
      'Access Granted': 'Acceso concedido',
      'Grant Access': 'Conceder acceso',
      'Configure your AI': 'Configura tu IA',
      'We will ask for some permissions to make sure you have the best experience':
          'Pediremos algunos permisos para asegurarnos de que tengas la mejor experiencia',
      'Configure your AI to work as you want':
          'Configura tu IA para que funcione como quieras',
      'Add your models': 'Añade tus modelos',
      'Add': 'Añadir',
      'Permissions': 'Permisos',
      'Granting these permissions ensures all features work seamlessly from the get-go.':
          'Otorgar estos permisos asegura que todas las funciones funcionen sin problemas desde el principio.',
      'Files and Folders': 'Archivos y carpetas',
      'Allows you to save chats history and temprorarily python files generated by LLM':
          'Te permite guardar el historial de chats y los archivos temporales de python generados por LLM',
      'Microphone': 'Micrófono',
      'Allows you to record your voice and send it to LLM':
          'Te permite grabar tu voz y enviarla a LLM',
      'Accessibility': 'Accesibilidad',
      'Allows you to use overlay, resize windows and more.':
          'Te permite usar superposiciones, cambiar el tamaño de las ventanas y más.',
      'Notifications': 'Notificaciones',
      'Allows you to receive notifications from the app.':
          'Te permite recibir notificaciones de la aplicación.',
      'Create new chat (only in chat)': 'Crear nuevo chat (solo en el chat)',
      'Escape/Cancel selection (only in chat)':
          'Escape/Cancelar selección (solo en el chat)',
      'Reset chat (only in chat)': 'Restablecer chat (solo en el chat)',
      'Copy last message to clipboard (only in chat)':
          'Copiar el último mensaje al portapapeles (solo en el chat)',
      'Include current chat history in conversation':
          'Incluir el historial de chat actual en la conversación',
      'Search in chat (only when input field is focused)':
          'Buscar en el chat (solo cuando el campo de entrada está enfocado)',
      'Open/Focus/Hide window': 'Abrir/Enfocar/Ocultar ventana',
      'Show overlay for selected text':
          'Mostrar superposición para el texto seleccionado',
      'Shortcuts': 'Atajos',
      'This is your quick shortcuts you can use anytime':
          'Estos son tus atajos rápidos que puedes usar en cualquier momento',
      'Continue': 'Continuar',
      'Edit prompt': 'Editar prompt',
      'edit_prompt_dialog_helper': '''Ayudantes:
\${lang} - el idioma del texto seleccionado
\${clipboardAccess} - si quieres activar el acceso al portapapeles para LLM
\${input} - el texto seleccionado''',
      'Title:': 'Título:',
      'Icon:': 'Icono:',
      'Generate a 3-5 words title based on this prompt: "{{input}}"':
          'Genera un título de 3-5 palabras basado en este prompt: "{{input}}"',
      'Prompt:': 'Prompt:',
      'Add data to prompt:': 'Añadir datos al prompt:',
      'User input': 'Entrada del usuario',
      'Current language': 'Idioma actual',
      'Clipboard access': 'Acceso al portapapeles',
      'Info about user': 'Información sobre el usuario',
      'Timestamp': 'Marca de tiempo',
      'System info': 'Información del sistema',
      'Tags (Use ; to separate tags)':
          'Etiquetas (Usa ; para separar las etiquetas)',
      'Tags': 'Etiquetas',
      'Do not show the main window after the prompt is run. The result will be shown in a push notification.\nUseful when you just want to copy the result to clipboard':
          'No mostrar la ventana principal después de ejecutar el prompt. El resultado se mostrará en una notificación push.\nÚtil cuando solo quieres copiar el resultado al portapapeles',
      'Silent': 'Silencioso',
      'If checked, the prompt will include system prompt with each activation':
          'Si está marcado, el prompt incluirá el prompt del sistema con cada activación',
      'Include System Prompt': 'Incluir prompt del sistema',
      'If checked, the prompt will include ALL messages from the conversation with each activation':
          'Si está marcado, el prompt incluirá TODOS los mensajes de la conversación con cada activación',
      'Show in chat field': 'Mostrar en el campo de chat',
      'Show in context menu': 'Mostrar en el menú contextual',
      'Show in home page': 'Mostrar en la página de inicio',
      'Show in overlay': 'Mostrar en la superposición',
      'Keybinding:': 'Atajo de teclado:',
      'Set keybinding': 'Establecer atajo de teclado',
      'Apply': 'Aplicar',
      'Add sub-prompt list': 'Añadir lista de sub-prompts',
      'Close': 'Cerrar',
      'Conversation style': 'Estilo de conversación',
      'Style': 'Estilo',
      'Conversation length': 'Duración de la conversación',
      'API token is empty!': '¡El token de la API está vacío!',
      'When you send a message, the app will use the system message along with your prompt. This value may differ from your own calculations because some additional information can be sent with each of your prompts.\nTotal is the total tokens that exists in current chat\nSent is the total tokens that you have sent\nReceived is the total tokens that you have received':
          'Cuando envías un mensaje, la aplicación usará el mensaje del sistema junto con tu prompt. Este valor puede diferir de tus propios cálculos porque se puede enviar información adicional con cada uno de tus prompts.\nTotal es el total de tokens que existen en el chat actual\nSent es el total de tokens que has enviado\nReceived es el total de tokens que has recibido',
      'Tokens total:': 'Tokens totales:',
      'sent:': 'enviado:',
      'received:': 'recibido:',
      'Text size': 'Tamaño del texto',
      'Include conversation': 'Incluir conversación',
      'Add system message': 'Añadir mensaje del sistema',
      'Capture screenshot': 'Capturar pantalla',
      'You need to obtain Brave API key to use web search':
          'Necesitas obtener la clave API de Brave para usar la búsqueda web',
      'Settings->API and URLs': 'Ajustes->API y URLs',
      'Disable web search': 'Desactivar búsqueda web',
      'Enable web search': 'Activar búsqueda web',
      'To prevent token overflows unnecessary cost we propose to limit the conversation length':
          'Para evitar el desbordamiento de tokens y costes innecesarios, proponemos limitar la duración de la conversación',
      'Max tokens to include': 'Máximo de tokens a incluir',
      'Min': 'Mín',
      'Med': 'Med',
      'Hight': 'Alto',
      'Max': 'Máx',
      'Select items to include in system prompt':
          'Selecciona los elementos a incluir en el prompt del sistema',
      'Knowledge about user': 'Conocimiento sobre el usuario',
      'City name': 'Nombre de la ciudad',
      'Weather': 'Clima',
      'User name': 'Nombre de usuario',
      'Current timestamp': 'Marca de tiempo actual',
      'OS info': 'Información del sistema operativo',
      'Summarize conversation and populate the knowledge about the user':
          'Resume la conversación y completa el conocimiento sobre el usuario',
      'Use memory about the user': 'Usar memoria sobre el usuario',
      'Auto play messages from ai':
          'Reproducir automáticamente los mensajes de la IA',
      'Will ask AI to produce buttons for each response. It will consume additional tokens in order to generate suggestions':
          'Pedirá a la IA que genere botones para cada respuesta. Consumirá tokens adicionales para generar sugerencias',
      'Do you want to enable suggestion helpers?':
          '¿Quieres activar los ayudantes de sugerencias?',
      'Enable': 'Activar',
      'No. Don\'t show again': 'No. No mostrar de nuevo',
      'Choose code block': 'Elegir bloque de código',
      'Dismiss': 'Cerrar',
      'Use "/" or type your message here':
          'Usa "/" para comandos o escribe tu mensaje aquí',
      'Settings': 'Ajustes',
      'General': 'General',
      'Appearance': 'Apariencia',
      'Tools': 'Herramientas',
      'User info': 'Información del usuario',
      'API and URLs': 'API y URLs',
      'On response': 'En respuesta',
      'Overlay': 'Superposición',
      'Storage': 'Almacenamiento',
      'Hotkeys': 'Teclas de acceso rápido',
      'About': 'Acerca de',
      'Open the window keybinding': 'Atajo de teclado para abrir la ventana',
      'Open the window': 'Abrir la ventana',
      'Take a screenshot keybinding':
          'Atajo de teclado para hacer una captura de pantalla',
      'Use visual AI': 'Usar IA visual',
      '[Not set]': '[No establecido]',
      'Push-to-talk with screenshot':
          'Pulsar para hablar con captura de pantalla',
      'Push-to-talk': 'Pulsar para hablar',
      'Show all keybindings': 'Mostrar todos los atajos de teclado',
      'Application storage location':
          'Ubicación del almacenamiento de la aplicación',
      'Delete temp cache? Size:': '¿Borrar caché temporal? Tamaño:',
      'Clear all data': 'Borrar todos los datos',
      'Overlay settings': 'Ajustes de la superposición',
      'Enable overlay': 'Activar superposición',
      'Show settings icon in overlay':
          'Mostrar icono de ajustes en la superposición',
      'Adaptive': 'Adaptativo',
      'Show suggestions after ai response':
          'Mostrar sugerencias después de la respuesta de la IA',
      'Brave API key (search engine) \$':
          'Clave API de Brave (motor de búsqueda) \$',
      'Text-to-Speech service:': 'Servicio de texto a voz:',
      'Global system prompt': 'Prompt global del sistema',
      'Customizable Global system prompt will be used for all NEW chats. To check the whole system prompt press button below':
          'El prompt global del sistema personalizable se utilizará para todos los chats NUEVOS. Para comprobar todo el prompt del sistema, pulse el botón de abajo',
      'Click here to check the whole system prompt':
          'Pulse aquí para comprobar todo el prompt del sistema',
      'Use ai to name chat': 'Usar la IA para nombrar el chat',
      'Can cause additional charges!': '¡Puede causar cargos adicionales!',
      'Audio and Microphone': 'Audio y micrófono',
      'Locale': 'Localización',
      'Launch at startup': 'Lanzar al inicio',
      'Prevent close app': 'Prevenir el cierre de la aplicación',
      'Show app in dock': 'Mostrar la aplicación en el dock',
      'Hide window title': 'Ocultar el título de la ventana',
      'User city': 'Ciudad del usuario',
      'Your name that will be used in the chat':
          'Tu nombre que se usará en el chat',
      'Your city name that will be used in the chat and to get weather':
          'El nombre de tu ciudad que se usará en el chat y para obtener el clima',
      'Include knowledge about user': 'Incluir conocimiento sobre el usuario',
      'Open info about User': 'Abrir información sobre el usuario',
      'Include user city name in system prompt':
          'Incluir el nombre de la ciudad del usuario en el prompt del sistema',
      'Include weather in system prompt':
          'Incluir el clima en el prompt del sistema',
      'Include user name in system prompt':
          'Incluir el nombre de usuario en el prompt del sistema',
      'Include current date and time in system prompt':
          'Incluir la fecha y hora actuales en el prompt del sistema',
      'Include system info in system prompt':
          'Incluir información del sistema en el prompt del sistema',
      'Learn about the user after creating new chat \$\$':
          'Aprender sobre el usuario después de crear un nuevo chat \$\$',
      'Function tools \$\$': 'Herramientas de función \$\$',
      'Toggle All': 'Alternar todo',
      'Auto copy to clipboard': 'Copiar automáticamente al portapapeles',
      'Auto open url': 'Abrir automáticamente la URL',
      'Generate images': 'Generar imágenes',
      'Additional tools': 'Herramientas adicionales',
      'Imgur (Used to upload your image to your private Imgur account and get image link)':
          'Imgur (Se utiliza para subir tu imagen a tu cuenta privada de Imgur y obtener el enlace de la imagen)',
      'Image Search engines': 'Motores de búsqueda de imágenes',
      'Enable annoy mode': 'Activar el modo molesto',
      'Use timer and allow AI to write you. Can cause additional charges!':
          'Usar el temporizador y permitir que la IA te escriba. ¡Puede causar cargos adicionales!',
      'Accent Color': 'Color de acento',
      'Theme mode': 'Modo de tema',
      'Light': 'Claro',
      'Dark': 'Oscuro',
      'Background': 'Fondo',
      'Use aero': 'Usar Aero',
      'Use acrylic': 'Usar acrílico',
      'Use transparent': 'Usar transparente',
      'Use mica': 'Usar Mica',
      'Transparency': 'Transparencia',
      'Set window as frameless': 'Establecer la ventana sin marco',
      'Restart the app to apply changes':
          'Reinicia la aplicación para aplicar los cambios',
      'Message Text size': 'Tamaño del texto del mensaje',
      'Basic Message Text Size': 'Tamaño básico del texto del mensaje',
      'Compact Message Text Size': 'Tamaño compacto del texto del mensaje',
      'Voice:': 'Voz:',
      'Read sample': 'Leer muestra',
      'Weather in': 'Clima en',
      'More': 'Más',
      'Edit': 'Editar',
      'Continue writing': 'Continuar escribiendo',
      'Explain this': 'Explicar esto',
      'Summarize this': 'Resumir esto',
      'Check grammar': 'Revisar la gramática',
      'Improve writing': 'Mejorar la escritura',
      'Translate': 'Traducir',
      'Answer with tags': 'Responder con etiquetas',
      'Search': 'Buscar',
      'Search...': 'Buscar...',
      'Chat rooms': 'Salas de chat',
      'Create new chat': 'Crear nuevo chat',
      'Create folder': 'Crear carpeta',
      'Deleted chats': 'Chats eliminados',
      'Storage usage': 'Uso del almacenamiento',
      'Refresh from disk': 'Actualizar desde el disco',
      'Add new': 'Añadir nuevo',
      'AI will be able to remember things about you':
          'La IA podrá recordar cosas sobre ti',
    },
  };
}

extension I18nExtension on String {
  String get tr {
    final localization = currentLocalization.value;
    return localization[this] ?? this;
  }

  String trFallback(String fallback) {
    final localization = currentLocalization.value;
    return localization.containsKey(this) ? localization[this]! : fallback;
  }
}
