#!/bin/bash -e

if [ "$#" -le 1 ]; then
  cat >&2<<ERROR
Error: Faltan parámetros.
Usa:
   $0 <nombre> <versión> [<plataforma>]
 Ejemplo:
   $0 vm 12.2.0 amd64
ERROR

  exit 1
fi

NAME="$1"
VERSION="$2"
PLATFORM="${3:-amd64}"

BASE_DIR="$PWD"
OUT_ISO="$BASE_DIR/build/debian-$VERSION-$PLATFORM-$NAME.iso"
PRESEED_FILE="$BASE_DIR/preseeds/$NAME.cfg"
IMAGE="debian-$VERSION-$PLATFORM-netinst.iso"
DOWNLOAD_MIRROR="https://cdimage.debian.org/mirror/cdimage"
DOWNLOAD_PATH="$VERSION/$PLATFORM/iso-cd/$IMAGE"
DOWNLOAD_DEST="$BASE_DIR/downloads"
OUT_DIR="$BASE_DIR/build/$VERSION-$PLATFORM-$NAME"

remote_exists() {
  curl --fail -I "$1" >/dev/null 2>&1
}

download_file() {
  echo "Descargando imagen base ..."
  DOWNLOAD_URL="$DOWNLOAD_MIRROR/release/$DOWNLOAD_PATH"
  if ! remote_exists "$DOWNLOAD_URL"; then
    # No es la última versión, buscar en archive
    DOWNLOAD_URL="$DOWNLOAD_MIRROR/archive/$DOWNLOAD_PATH"
    if ! remote_exists "$DOWNLOAD_URL"; then
      error "
ERROR: La imagen '$DOWNLOAD_PATH' no fue encontrada en el sevidor."
    fi
  fi

  curl --fail -L# "$DOWNLOAD_URL" -o "$2" || error "
ERROR: No se pudo descargar la imagen desde $1
       Puedes reintentarlo o descargar la imagen manualmente y colocarla en:
          $2"
}

error() {
  echo "$@" >&2
  exit 1
}

missing_pkg() {
  error "
ERROR: El paquete $1 no está instalado.
       Instálalo con:
         sudo apt-get install -y $1"
}

_gunzip() {
  [ -f "$1" ] || error "
ERROR: no existe: $1
       es posible que un paso anterior haya fallado"

  gunzip "$1"
}

if [ ! -f "$PRESEED_FILE" ]; then
  error "
ERROR: $PRESEED_FILE no existe
        Crea una a partir de preseed.cfg"
fi

cat <<MESSAGE
Creando nueva imagen: $VERSION-$PLATFORM-$NAME ...

MESSAGE

genisoimage --version >/dev/null 2>&1 || missing_pkg "genisoimage"
ed --version >/dev/null 2>&1 || missing_pkg "ed"
xorriso --version >/dev/null 2>&1 || missing_pkg "xorriso"

[ -d "$OUT_DIR" ] || mkdir -p "$OUT_DIR"

## Descargar y desempaquetar la imagen
if [ ! -d "$OUT_DIR/isofiles/debian" ]; then
  [ -f "$DOWNLOAD_DEST/$IMAGE" ] || download_file $DOWNLOAD_PATH "$DOWNLOAD_DEST/$IMAGE"

  echo "Desempaquetando la imagen ..."

  xorriso -osirrox on -indev "$DOWNLOAD_DEST/$IMAGE" -extract / "$OUT_DIR/isofiles/"
fi

## Sacar vesamenu
ISOLINUX="$OUT_DIR/isofiles/isolinux/isolinux.cfg"
if grep "default vesamenu.c32" $ISOLINUX >/dev/null; then
  echo "Parcheando $ISOLINUX ..."

  chmod +w "$ISOLINUX"
  ed -s "$ISOLINUX" <<EOF
/default vesamenu.c32/
d
wq
EOF

  chmod -w "$ISOLINUX"
fi

## Sacar timeout
GRUB="$OUT_DIR/isofiles/boot/grub/grub.cfg"
if ! grep "set timeout_style=hidden" "$GRUB" >/dev/null; then
  echo "Parcheando $GRUB ..."

  chmod +w "$GRUB"
  ed -s "$GRUB" <<EOF
0i
set timeout_style=hidden
set timeout=0
set default=1
.
wq
EOF
  chmod -w "$GRUB"
fi

## PRESEED - para insertar el preseed, descomprimimos el initrd.gz, desempaquetamos
#            el initrd, copiamos el preseed.cfg,  empaquetamos el initrd y lo comprimimos.
#
#            En resumen:
#               1. Descomprimir
#                2. Desempaquetar
#                 3. Copiar
#                4. Empaquetar
#               5. Comprimir
#
#            Hay que tener en cuenta que algunos directorios/ficheros no son escribibles, por
#            eso les cambiamos temporalmente los permisos.
chmod +w -R "$OUT_DIR/isofiles/install.amd"

# ver si existe cualquier directorio, nada especial con etc
if [ ! -d "$OUT_DIR/tmp/initrd.contents/etc" ]; then
  if [ ! -f "$OUT_DIR/isofiles/install.amd/initrd" ]; then
    # 1. Descomprimir
    _gunzip "$OUT_DIR/isofiles/install.amd/initrd.gz"
  fi

  mkdir -p "$OUT_DIR/tmp/initrd.contents"

  pushd "$OUT_DIR/tmp/initrd.contents" >/dev/null
  # 2. Desempaquetar
  # Necesitamos sudo acá porque sino los permisos se rompen. Creo.
  sudo cpio -idm < "$OUT_DIR/isofiles/install.amd/initrd"
  popd >/dev/null
fi

[ -f "$OUT_DIR/tmp/initrd" ] && rm "$OUT_DIR/tmp/initrd"

pushd "$OUT_DIR/tmp/initrd.contents" >/dev/null
# 3. Copiar cosas
[ -d var/lib/undeb ] || sudo mkdir var/lib/undeb

sudo cp "$PRESEED_FILE" preseed.cfg
sudo rsync -a --no-owner "$BASE_DIR/tools/" var/lib/undeb

# 4. Empaquetar
# Necesitamos sudo acá también porque permisos.
find . | sudo cpio -H newc -o > "$OUT_DIR/tmp/initrd"
popd >/dev/null

rm -f "$OUT_DIR/isofiles/install.amd/initrd"{,.gz}
mv "$OUT_DIR/tmp/initrd" "$OUT_DIR/isofiles/install.amd/initrd"

# 5. Comprimir
gzip "$OUT_DIR/isofiles/install.amd/initrd"
chmod -w -R "$OUT_DIR/isofiles/install.amd"

pushd "$OUT_DIR/isofiles"

chmod +w md5sum.txt
md5sum `find -follow -type f` > md5sum.txt
chmod -w md5sum.txt

popd

## Generar la imagen con la estructura que tenemos en nuestro espacio de trabajo
chmod +w "$OUT_DIR/isofiles/isolinux/isolinux.bin"
genisoimage -r -J \
  -b "isolinux/isolinux.bin" \
  -c "isolinux/boot.cat" \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -o "$OUT_ISO" \
  "$OUT_DIR/isofiles" > /dev/null
chmod -w "$OUT_DIR/isofiles/isolinux/isolinux.bin"

echo " ***********"
echo "Imagen creada satisfactoriamente."

chsum -a sha1 $OUT_ISO
