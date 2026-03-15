# YaYa Eats — App Mobile (Flutter)

Aplicacion movil para clientes y riders. Construida con Flutter.

---

## Requisitos

- Flutter SDK 3.9+
- Android Studio / emulador configurado
- JDK 17+
- Keystore firmado (para release): `android/app/yaya-eats.jks`

---

## Desarrollo local

### 1. Variables de entorno

```bash
cp .env.example .env
```

Valores clave para local (`.env`):

```env
API_BASE_URL=http://10.0.2.2:3002/api
OWUI_BASE_URL=http://10.0.2.2:3000
MAPBOX_ACCESS_TOKEN=pk.eyJ1IjoiYXJyb3lvYW5nZWwiLCJhIjoiY21...
OWUI_API_KEY=sk-...
OWUI_MODEL=yayaeats
```

> **Importante:** En el emulador Android, `localhost` no apunta a tu PC.
> Usa `10.0.2.2` para conectarte al host desde el emulador.
> En dispositivo fisico conectado por USB, usa la IP de tu PC en la red local (ej. `192.168.1.X`).

### 2. Correr en emulador

```bash
# Lanzar emulador
flutter emulators --launch Pixel_6_API_36

# Esperar que aparezca el dispositivo
flutter devices --device-timeout 120

# Correr la app
flutter run -d emulator-5554
```

### 3. Correr en dispositivo fisico

```bash
# Ver dispositivos conectados
flutter devices

# Correr en el dispositivo
flutter run -d <device-id>
```

---

## Generar APK para QA

El APK de QA apunta al servidor de produccion `https://api.yaya.work`.

### Pasos

```bash
# 1. Usar variables de QA
copy .env.qa .env        # Windows
# cp .env.qa .env        # Mac/Linux

# 2. Limpiar y obtener dependencias
flutter clean
flutter pub get
flutter run -d emulator-5554

# 3. Generar iconos (solo si cambiaste el icono)
dart run flutter_launcher_icons

# 4. Build APK firmado
flutter build apk --release
```

El APK queda en:
```
build/app/outputs/flutter-apk/app-release.apk
```

### Instalar directo en el celular (USB)

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

O transferir el archivo `app-release.apk` al celular e instalar manualmente
(activar "Instalar desde fuentes desconocidas" en Ajustes > Seguridad).

### Restaurar .env local despues del build

```bash
copy .env.example .env    # Windows
# cp .env.example .env    # Mac/Linux
# Editar .env y poner las URLs de local
```

---

## App Bundle para Play Store

```bash
copy .env.qa .env
flutter build appbundle --release
```

El bundle queda en:
```
build/app/outputs/bundle/release/app-release.aab
```

---

## Keystore (firma de release)

El keystore esta en `android/app/yaya-eats.jks`.
Las credenciales estan en `android/key.properties` (no subir al repositorio).

```properties
storePassword=YayaEats2026!
keyPassword=YayaEats2026!
keyAlias=yaya-eats
storeFile=yaya-eats.jks
```

---

## Estructura de URLs

| Entorno | API URL |
|---------|---------|
| Local (emulador) | `http://10.0.2.2:3002/api` |
| Local (dispositivo) | `http://192.168.X.X:3002/api` |
| QA | `https://api.yaya.work/api` |
