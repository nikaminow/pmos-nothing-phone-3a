<div align="center">

# postmarketOS на Nothing Phone (3a)

**Linux 7.2 (mainline) + Plasma Mobile на Nothing Phone (3a) «Asteroids» (SM7635 / milos)**

![Device](https://img.shields.io/badge/устройство-Nothing%20Phone%20(3a)-black?style=for-the-badge)
![Kernel](https://img.shields.io/badge/Linux-7.2%20mainline-yellow?style=for-the-badge&logo=linux&logoColor=white)
![UI](https://img.shields.io/badge/UI-Plasma%20Mobile-1d99f3?style=for-the-badge&logo=kde&logoColor=white)
![Boot](https://img.shields.io/badge/загрузка-только%20из%20RAM-2ea44f?style=for-the-badge)

[English](README.md) · **Русский**

[**Скачать**](../../releases/latest) · [Как запустить](#-как-запустить) · [Что работает](#-что-работает) · [Вопросы](#-частые-вопросы)

</div>

> [!NOTE]
> Система запускается **только из оперативной памяти** (`fastboot boot`). Ничего не прошивается:
> Android и все ваши данные остаются на месте. Перезагрузили телефон — снова Android.

## ✅ Что работает

| | Что | |
|:-:|---|---|
| ✅ | Plasma Mobile, сенсор | |
| ✅ | Экран 120 Гц | |
| ✅ | Видеоускорение (Adreno 810) | |
| ✅ | Wi-Fi, Bluetooth | |
| ✅ | Связь: звонки, SMS, мобильный интернет | SIM в слоте 1; слот 2 работает не со всеми картами |
| ✅ | Заряд батареи | |
| ✅ | Автоповорот, датчик света, приближения, компас | |
| ✅ | Вибрация | |
| ✅ | Glyph-подсветка, фонарик | |
| ✅ | Время | берётся с компьютера при загрузке |
| 🚧 | Динамики | отключены, пока не готова защита динамиков |
| 🚧 | Камеры | в работе |
| ❌ | Микрофоны, наушники | нет драйвера кодека WCD9378 |
| ❌ | USB-флешки, вывод на монитор | |

Проверено только на Phone (3a). На (3a) Pro не проверялось.

## 🚀 Как запустить

### Что нужно

- **Разблокированный загрузчик.** Разблокировка стирает данные телефона. Если загрузчик уже
  разблокирован, ничего стирать не придётся.
- **Компьютер** с Windows или Linux и **USB-кабель**.
- **[Android platform-tools](https://developer.android.com/tools/releases/platform-tools)** (`adb` и `fastboot`).
- **[Python 3.8+](https://www.python.org/downloads/)**. На Windows при установке отметьте «Add python.exe to PATH».
- **Файлы из [последнего релиза](../../releases/latest)**, сложенные в одну папку: `pmos-3a-boot.img`, `rootfs.sqfs`, `send-rootfs.py`.

> [!TIP]
> Проверить, что файлы скачались целиком: `certutil -hashfile rootfs.sqfs SHA256` (Windows)
> или `sha256sum rootfs.sqfs` (Linux). Результат сравните с `SHA256SUMS.txt`.

### Шаги

**1. Переведите телефон в режим загрузчика.**
Выполните `adb reboot bootloader` (нужна отладка по USB) или выключите телефон и зажмите
<kbd>Питание</kbd> + <kbd>Громкость −</kbd>.

**2. Откройте терминал в папке с файлами.**
На Windows: <kbd>Shift</kbd> + правый клик по папке → «Открыть в Терминале».

**3. Загрузите образ.** Эта команда ничего не прошивает, только запускает систему из памяти:

```sh
fastboot boot pmos-3a-boot.img
```

На экране останется заставка. Телефон появится на компьютере как USB-COM-порт.
Подождите 10–15 секунд.

**4. Отправьте систему на телефон** (~900 МБ, 2–3 минуты):

| Windows | Linux |
|---|---|
| `python send-rootfs.py` | `sudo systemctl stop ModemManager`<br>`sudo python3 send-rootfs.py` |
| порт находится сам, драйверы не нужны | при необходимости `--port /dev/ttyACM0` |

**5. Готово.** Примерно через минуту запустится Plasma Mobile.
Пользователь `user`, пароль **`147147`**.

### Как вернуться в Android

Зажмите <kbd>Питание</kbd>, пока телефон не перезагрузится. Все изменения, которые вы сделали в
postmarketOS (настройки, Wi-Fi, установленные приложения), хранятся только в памяти и пропадают
после перезагрузки.

## ❓ Частые вопросы

<details>
<summary><b>Это безопасно для моих данных?</b></summary>

Да. Используется только `fastboot boot`, а не `fastboot flash`. Разделы телефона подключаются
только для чтения: оттуда берутся прошивки модема, Wi-Fi, видеочипа и датчиков. Ничего не записывается.
</details>

<details>
<summary><b><code>fastboot boot</code> выдаёт ошибку</b></summary>

Загрузчик заблокирован или platform-tools устарели. Скачайте свежие platform-tools по ссылке выше.
</details>

<details>
<summary><b>Скрипт пишет «no serial port for the phone»</b></summary>

Подождите ещё 10–15 секунд после `fastboot boot`. Попробуйте другой кабель или порт, лучше USB на
самом компьютере, а не через хаб. На Linux проверьте, что ModemManager остановлен.
</details>

<details>
<summary><b>Передача оборвалась или телефон ушёл в Android</b></summary>

Начните с шага 1. Во время передачи не трогайте кабель.
</details>

<details>
<summary><b>После передачи белый или чёрный экран</b></summary>

Экран переинициализируется сам, подождите минуту. Если не помогло, перезагрузите телефон и
повторите: иногда заставка загрузчика мешает экрану запуститься.
</details>

<details>
<summary><b>Можно установить насовсем?</b></summary>

Пока нет. Установочный образ будет позже, когда заработают звук и камера.
</details>

<details>
<summary><b>Можно ставить приложения?</b></summary>

Да, через Discover (магазин) или `sudo apk add ...` в терминале QMLKonsole. Но после
перезагрузки они пропадут. Android-приложения (APK) не поддерживаются.
</details>

## 🛠 Сборка из исходников

Порядок сборки и устройство загрузки описаны в [английском README](README.md#-building),
подробный журнал разработки — в [PMOS-3A-PLAN.md](PMOS-3A-PLAN.md).
Основа — [Nura](https://github.com/UnderWeek/nura-nothing-phone-4a) для Phone (4a) (тот же SoC),
ядро [milos-mainline](https://github.com/milos-mainline/linux) 7.2.
