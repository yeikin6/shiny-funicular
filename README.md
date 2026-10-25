# Robá una Estrella

Juego de farmeo para Roblox del estilo "Steal a ___". Caen estrellas en un cráter, las llevás a tu observatorio y te dan Polvo por segundo. Los demás pueden robártelas.

Diseño completo: [Robá una Estrella: diseño del juego](https://claude.ai/artifact/NadBCskurSd36XcTD27AJX).

## Primera vez (se hace una sola vez)

Todo esto va en la **terminal** (PowerShell), no en Studio.

1. Instalá Rokit: bajá el zip de Windows de [las releases](https://github.com/rojo-rbx/rokit/releases), descomprimilo y corré `.\rokit.exe self-install` en esa carpeta. Cerrá la terminal y abrí una nueva.
2. Bajá el juego y las herramientas:

   ```
   mkdir $HOME\dev
   cd $HOME\dev
   git clone https://github.com/yeikin6/shiny-funicular
   cd shiny-funicular
   rokit install
   rojo plugin install
   ```

3. Cerrá Studio si lo tenías abierto y volvé a abrirlo. En la pestaña **Plugins** ahora aparece **Rojo**.

## Cada vez que quieras jugar

1. En la terminal, dentro de `shiny-funicular`: `rojo serve` (dejala abierta).
2. En Studio, abrí un place **Baseplate** y borrá `Baseplate` y `SpawnLocation` del Explorer.
3. Plugins → **Rojo** → **Connect**. El código aparece solo en Studio.
4. Apretá **Play**. Para probar robos: pestaña **Test** → Clients and Servers → 2 jugadores → **Start**.

## Una vez por place

- Para que se guarde el progreso: Home → Game Settings → Security → activá **Enable Studio Access to API Services** (antes tenés que publicar el place con File → Publish to Roblox). Si no lo activás, igual se puede jugar, pero no se guarda nada.
- Game Settings → Places → **Max Players: 6**, porque hay 6 parcelas por servidor.
- En el Explorer, seleccioná **Lighting** y en Properties poné **Technology: Future**. El resto de la iluminación nocturna la arma el código.

En Studio la espera entre tormentas es de 24 s y la espera entre eventos de 3 min, para poder probarlos. En el juego publicado son 4 y 30 min.

## Dónde está cada cosa

- `src/shared/Config.luau`: todos los números del juego (precios, tiempos, rarezas). Si querés ajustar el balance, se toca acá.
- `src/server/`: la lógica del servidor (estrellas, bases, guardado, rebirth, leaderboard).
- `src/client/`: el HUD y los prompts.
