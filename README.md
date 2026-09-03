# incrementale-godot

Reconstruction de [Incrementable](https://github.com/juanrobin09-stack/Incrementable) (jeu incremental/idle où le joueur incarne une force de la nature qui déclenche des catastrophes sur un village) sur le moteur **Godot 4.x**.

Reconstruction indépendante, pas un portage automatique : le rendu canvas, le HUD CSS et la logique JS de l'original ne se copient pas tels quels dans Godot — chaque couche est réécrite dans son propre paradigme (nœuds/scènes, `Control`/thèmes, GDScript).

## État actuel

- [x] Squelette du projet (`project.godot`, Godot 4.x, rendu GL Compatibility)
- [x] Couche de données pures (`scripts/game_data.gd`, autoload `GameData`) : catastrophes, synergies, objectifs (conditions déclaratives), Arbre du Chaos — traduction fidèle des tables de `script.js` de l'original
- [x] Logique d'état/économie (`scripts/game_state.gd`, autoload `GameState`) : achats (catastrophes et nœuds de l'Arbre du Chaos), coûts et production, déblocages, objectifs, calcul du KO, sauvegarde/chargement (`user://`), progression hors-ligne, boucle de jeu auto-pilotée
- [x] HUD fonctionnel (`scripts/main.gd` + `scripts/hud/`) : barre du haut, dock des catastrophes + carte d'achat, modales hors-ligne/reset — construit en code, thème par défaut. **Vérifié en jeu : fonctionne.**
- [x] Arbre du Chaos (`scripts/hud/chaos_tree_overlay.gd`) : disposition radiale, connecteurs, pan/zoom, inspecteur — mêmes constantes/formules que l'original. **Vérifié en jeu : fonctionne.**
- [x] Rendu du village statique (`scripts/world/`) : ciel, collines, sol, route, 5 maisons, 8 arbres, puits, clôture, lampadaire, moulin, buissons, parterres de fleurs — porté fidèlement depuis `render.js` (mêmes couleurs, mêmes proportions, même disposition fractionnelle), rendu à basse résolution logique puis mis à l'échelle sans lissage pour garder le style pixel art. **Vérifié en jeu : fonctionne, aucune correction nécessaire.**
- [x] Météo — pluie, éclair, teinte d'orage (`scripts/world/weather_layer.gd` + `background_layer.gd`). **Vérifié en jeu : fonctionne, aucune correction nécessaire.** La pluie penche et accélère selon le vent (direction + force partagées avec `WindEngine`, mêmes formules que l'original). **Poussé, pas encore vérifié.**
- [x] Moteur de vent (`scripts/world/wind_engine.gd`) + balancement des arbres/buissons/clôture + traînées de vent + nuages qui dérivent. **Vérifié en jeu : fonctionne, aucune correction nécessaire.**
- [~] Dégâts du vent — arbres qui plient et tombent, maisons qui se fissurent/perdent leur toit/s'effondrent en ruines, moulin qui peut aussi s'effondrer, débris qui volent (`tree_sprite.gd`, `house_sprite.gd`, `windmill_sprite.gd`, `debris_fragment.gd`, `dust_puff.gd`, `debris_spawner.gd`). **Écart voulu par rapport à l'original, demandé explicitement** : une fois tombé/effondré, ça ne repousse/reconstruit jamais — l'original fait revenir les arbres et reconstruit les maisons après un temps calme, on a choisi de ne pas le garder. **Poussé mais pas encore vérifié.**
- [ ] Fumée des cheminées (détail mineur, pas encore fait)
- [ ] Son du tonnerre (synthétisé, comme l'original) sur les éclairs — pas nécessaire pour l'instant
- [ ] Passe de fidélité visuelle (bois/parchemin/or, dock en pierre) + curseur personnalisé selon le survol — à faire ensemble, nécessitera des allers-retours avec des captures d'écran, comme pour l'Arbre du Chaos sur la version web

Vérifié dans l'éditeur Godot 4.7 : `GameData` expose des données cohérentes à l'exécution, `GameState` a été validé bout en bout (45 vérifications automatiques, toutes au vert), le HUD fonctionnel, l'Arbre du Chaos, le village statique, la météo et le moteur de vent ont tous été confirmés jouables/corrects à l'écran.
