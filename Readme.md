# undeb

El objetivo de este proyecto es facilitar la creación de imágenes personalizadas para la
instalación de Debian, orientándonos principalmente en instalaciones desatendidas para máquinas
virtuales.

## Requerimientos

Se necesita algún paquete para poder realizar el proceso de generación:

    sudo apt-get install -y xorriso

## Preseed

Debes crear un archivo preseed con la configuración preferida. Puedes encontrar un ejemplo
en https://www.debian.org/releases/stable/example-preseed.txt, o más información en:
https://wiki.debian.org/DebianInstaller/Preseed

    Nota:
    Este archivo será distribuído en la imagen creada, asegúrate de no incluir contraseñas
    en texto plano, o información delicada (por ejemplo, muchos detalles sobre un servidor que
    estará accesible públicamente). Es posible que quieras mantener tus archivos de preseed
    privados.

Puedes crear el hash para una contraseña (esto debería ser seguro para compartir online, pero
debes recuerda siempre manejar las contraseñas con cuidado), con, por ejemplo, el siguiente
comando:

```
python3 -c 'import crypt; print(crypt.crypt("<contraseña>", crypt.METHOD_SHA512))'
```

    Nota:
    No sé de dónde saqué este ejemplo, pero parece estar medio obsoleto, puede dejar de
    estar disponible en un futuro cercano.

## Uso

```
$ curl https://www.debian.org/releases/stable/example-preseed.txt > preseeds/web.cfg
$ vim preseeds/web.cfg # editar a gusto
$ bin/generate.sh web 12.4.0 # genera la imagen
$ bin/test.sh build/debian-12.4.0-amd64-web.iso # prueba la imagen en una máquina virtual
```
