# MaTi3D – éles telepítés

A publikus Angular SSR-rel, Node.js-ben fut. Az admin statikus Angular-build,
saját Nginx-konténerben. A gateway a `/`, `/admin/` és `/api/` útvonalakat kezeli.
A publikus oldal jelszó nélkül elérhető. Az admin felület és a fenntartott
`/api/admin/` névtér HTTP Basic Auth védelmet kap, amíg nincs saját bejelentkezés.
A többi `/api/` útvonal publikus; későbbi védett API-khoz alkalmazásszintű
hitelesítést és jogosultságkezelést kell készíteni.

## Jelenlegi VPS-állapot

- Domain: `mati3d.hu` és `www.mati3d.hu`, IP: `194.182.85.127`.
- Checkout: `/var/www/mati3d.hu/app`.
- Jelenlegi landing: `/var/www/mati3d.hu/public`.
- Aktív Nginx-konfiguráció: `/etc/nginx/sites-enabled/mati3d.hu`.
- Meglévő tanúsítvány: `/etc/letsencrypt/live/mati3d.hu/`.
- Új gateway: `127.0.0.1:18081`; Docker-hálózat: `172.30.33.0/24`.

A tanúsítvány és annak megújítása már létezik. Nincs új Certbot service/timer,
IP-challenge és nincs 18444-es publikus port. A meglévő 443-as HTTPS hostot
az utolsó lépésben kapcsoljuk át a konténerekre.

## 1. A fájlok feltöltése saját gépről

A csomag teljes tartalmát a helyi MaTi3D repo gyökerébe kell másolni,
a mappák egyesítésével és az azonos fájlok felülírásával. Tartalmaz Dockerfile-okat,
a publikus oldal SSR-beállítását és az API proxybeállítását is.
A `.env.example` példa; tényleges `.env` és htpasswd jelszófájl nincs a csomagban.

Commit és push után a VPS-en:

```bash
cd /var/www/mati3d.hu/app
git pull --ff-only
```

## 2. Környezeti változók és adminjelszó

A VPS-en Docker Engine + Compose v2 (`up --wait` támogatással), Nginx, Git,
OpenSSL és `htpasswd` szükséges. A deployfelhasználó férjen hozzá a Dockerhez.
A portokat és az alhálózatot már ellenőriztük; későbbi ütközéskor a `.env`
`DEPLOY_SUBNET` és `GATEWAY_IP` értékét együtt kell módosítani.

Első telepítéskor, ha még nincs `.env`:

```bash
cd /var/www/mati3d.hu/app
cp .env.example .env
chmod 600 .env
nano .env
```

A `POSTGRES_PASSWORD` helyére állíts be egyedi, véletlen hex jelszót
(például `openssl rand -hex 24` kimenetét). A hex forma elkerüli a connection
string speciális karaktereinek problémáját. Meglévő `.env`-et ne írj felül;
abban vezesd át az új változóneveket a `.env.example` alapján.

Az adminhoz készíts külön, legalább 24 véletlen karakteres jelszót:

```bash
htpasswd -cm deploy/admin.htpasswd matyi
chmod 644 deploy/admin.htpasswd
```

A `-c` csak az első létrehozáskor kell, mert felülírná a meglévő fájlt.
A jelszófájl és a `.env` ignorálva van Gitben. A konténernek olvasnia kell a
hash-fájlt, ezért annak módja 644; a checkout könyvtárát korlátozhatod 750-re.
A publikus oldal látogatói nem kapnak jelszókérést.

## 3. Konténerek indítása, a landing cseréje nélkül

```bash
bash deploy/deploy.sh
```

Ez buildel, ellenőrzi a Compose-konfigurációt, megvárja az alkalmazások
healthcheckjét és újratölti a gatewayt, hogy az új konténercímeket használja.
A root `docker-compose.yml` továbbra is helyi PostgreSQL-fejlesztéshez való;
az éles telepítés a `deploy/compose.yml` fájlt használja, önálló projektnévvel
és volumennel. PostgreSQL, API, SSR és admin nem publikálnak hostportot.

A helyi próba előtt kérd be az adminjelszót a shellbe, ne írd parancssorba:

```bash
read -r -p 'Admin felhasználó: ' ADMIN_USER
read -r -s -p 'Admin jelszó: ' ADMIN_PASSWORD
printf '\n'
export ADMIN_USER ADMIN_PASSWORD
SITE_URL=http://127.0.0.1:18081 bash deploy/smoke.sh
unset ADMIN_PASSWORD ADMIN_USER
```

A smoke ellenőrzi a jelszó nélküli SSR-t és API health választ, az admin
jelszóvédelmét, a statikus admin JS-t és az admin belső útvonal újratöltését.
A jelenlegi API nem használja még a PostgreSQL-t: a `mati3d` connection string
előkészített, a healthcheck nem bizonyít adatbázis-kapcsolatot és nem migrál.
A teljes konténeres ellenőrzést a VPS vagy GitHub Actions futtatja;
a csomag készítési környezetében Docker és .NET SDK nem volt elérhető.
A két Angular-build és a Node SSR futása a korábbi, változatlan appkóddal sikeres.

## 4. Átkapcsolás éles HTTPS-re

Csak sikeres konténeres smoke után. Ellenőrizd, hogy a sites-enabled fájl
hova mutat, majd a tényleges célfájlt mentsd és írd felül:

```bash
cd /var/www/mati3d.hu/app
nginx_target=$(readlink -f /etc/nginx/sites-enabled/mati3d.hu)
sudo cp -a "$nginx_target" /etc/nginx/mati3d.hu.before-app
sudo cp deploy/host-nginx.conf.example "$nginx_target"
sudo nginx -t && sudo systemctl reload nginx
```

A mentés az `/etc/nginx/mati3d.hu.before-app` fájlba kerül, a betöltött
sites-enabled könyvtáron kívül. Sikertelen `nginx -t` esetén ne reloadolj;
a mentésből állítsd vissza az eredeti konfigurációt.

A 18081-es portot ne nyisd ki a tűzfalon. Az oldal a már engedélyezett
443-on működik. Elérés: https://mati3d.hu/ és https://mati3d.hu/admin/.
A meglévő `/public` landing fájljait nem kell törölni.

Az éles cím vizsgálata ugyanazzal a smoke scripttel végezhető, ezúttal
`SITE_URL=https://mati3d.hu` értékkel. A tanúsítvány ellenőrzése nincs kikapcsolva.

## 5. GitHub Actions

A workflow neve **Production deploy**. A korábbi csomag felülírhatósága miatt
fájlneve `.github/workflows/private-preview.yml`; tartalma már éles konfiguráció.
PR-nél és `main` pushnál felépíti és elindítja a konténereket, majd smoke-ot futtat.
A CI véletlen, ideiglenes adatbázis- és adminjelszót használ.

VPS-deploy csak kézi **Run workflow** indításra, `main`-ről, sikeres CI után
fut, a **production** GitHub environmentben. Beállításai:

| Típus | Név | Érték |
|---|---|---|
| Secret | `VPS_HOST` | `194.182.85.127` |
| Secret | `VPS_USER` | `vhmware`, vagy külön deployfelhasználó |
| Secret | `VPS_SSH_KEY` | Deploy SSH privát kulcs |
| Secret | `VPS_KNOWN_HOSTS` | Megbízható VPS-konzolon ellenőrzött SSH hostkulcs bejegyzése |
| Secret | `ADMIN_USER` | A htpasswd felhasználója |
| Secret | `ADMIN_PASSWORD` | A htpasswd-hez használt jelszó |
| Variable | `SITE_URL` | `https://mati3d.hu` |

A publikus SSH-kulcs kerüljön a VPS-felhasználó authorized_keys fájljába.
A workflow a CI által ellenőrzött commit SHA-t checkoutolja a VPS-re.
Az első Nginx-átkapcsolást kézzel kell elvégezni; a workflow azt nem módosítja.
A checkoutnak tisztának kell lennie a Git által követett fájlok tekintetében.
A `.env` és `deploy/admin.htpasswd` ignorált fájlként marad meg.

## 6. Frissítés, mentés és visszaállítás

Frissítés előtt jegyezd fel a futó SHA-t (`git rev-parse HEAD`) és készíts
PostgreSQL-mentést védett, checkouton kívüli mentési könyvtárba:

```bash
docker compose --env-file .env -f deploy/compose.yml exec -T postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > /biztonsagos/mentesi-utvonal/mati3d.sql
```

A mentési útvonal helykitöltő: válassz létező, korlátozott hozzáférésű könyvtárat.
Kézi frissítés: `git fetch origin main`, `git checkout --detach origin/main`,
majd `bash deploy/deploy.sh`. Detach után következő frissítéshez is ezt használd,
ne a sima `git pull` parancsot. Rövid kiesés lehetséges.

Kód-visszaállítás: `git checkout --detach <korábbi-SHA>`, majd deploy script.
Későbbi migrációknál a kód visszaállítása nem feltétlenül elég az adatbázishoz.
A landingre visszakapcsoláshoz a host Nginx mentését állítsd vissza, majd
`sudo nginx -t && sudo systemctl reload nginx`.
Az éles VPS-en ne futtass `down -v` parancsot, ha meg akarod tartani az adatokat.

A 100 MB-os proxy feltöltési limit mindkét Nginxben szerepel; a tényleges
fájlfeltöltő funkció és az API saját feltöltési limitje külön fejlesztés.
