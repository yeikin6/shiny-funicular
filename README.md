# Robá una Estrella

Juego de farmeo para Roblox del estilo "Steal a ___". Caen estrellas en un cráter central; las llevás a tu observatorio, maduran con el tiempo y producen Polvo Estelar por segundo. Los demás pueden robártelas.

Diseño completo: [Robá una Estrella: diseño del juego](https://claude.ai/artifact/NadBCskurSd36XcTD27AJX).

## Cómo correrlo

1. Instalá [Rokit](https://github.com/rojo-rbx/rokit) y corré `rokit install` en la raíz. Eso baja Rojo, StyLua y Selene con las versiones fijadas en `rokit.toml`.
2. Instalá el plugin de Rojo en Studio (`rojo plugin install`).
3. En Studio, abrí un place nuevo con la plantilla **Baseplate**, borrá el `Baseplate` y el `SpawnLocation`; el mapa se genera por código.
4. `rojo serve` y conectate desde el plugin.
5. Para que se guarden los datos en Studio: Game Settings → Security → **Enable Studio Access to API Services**. Sin eso se juega igual, pero no persiste nada (lo avisa por consola).
6. Para probar robos: Test → Clients and Servers → 2 jugadores.

Ajustá **Max Players a 6** en Game Settings: hay 6 parcelas por servidor.

## Estructura

| Ruta | Qué hace |
| --- | --- |
| `src/shared/Config.luau` | Todos los números tuneables |
| `src/shared/Economy.luau` | Fórmulas puras: ingreso, madurez, rebirth, score del leaderboard |
| `src/shared/Format.luau` | Formateo de números grandes |
| `src/shared/Types.luau` | Tipos compartidos |
| `src/shared/Remotes.luau` | RemoteEvents (solo pedidos; el estado viaja por atributos del Player) |
| `src/server/Main.server.luau` | Orden de arranque |
| `src/server/MapBuilder.luau` | Mapa gris: piso, cráter, parcelas, tablero |
| `src/server/DataService.luau` | DataStore con reintentos y session locking |
| `src/server/BaseService.luau` | Parcelas, pedestales, ingreso, cobro, cúpula |
| `src/server/StarService.luau` | Lluvia de estrellas, agarrar, cargar, colocar, robar, soltar |
| `src/server/RebirthService.luau` | Rebirth |
| `src/server/LeaderboardService.luau` | Leaderboard global en OrderedDataStore |
| `src/client/HudController.luau` | HUD y botones |
| `src/client/PromptController.luau` | Qué prompts ve cada jugador |

## Chequeo de tipos

Todos los archivos son `--!strict` y pasan `luau-lsp analyze` sin errores:

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions=globalTypes.d.luau --platform=roblox src
```
