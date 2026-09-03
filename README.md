# incrementale-godot

Reconstruction de [Incrementable](https://github.com/juanrobin09-stack/Incrementable) (jeu incremental/idle où le joueur incarne une force de la nature qui déclenche des catastrophes sur un village) sur le moteur **Godot 4.x**.

Reconstruction indépendante, pas un portage automatique : le rendu canvas, le HUD CSS et la logique JS de l'original ne se copient pas tels quels dans Godot — chaque couche est réécrite dans son propre paradigme (nœuds/scènes, `Control`/thèmes, GDScript).

## État actuel

- [x] Squelette du projet (`project.godot`, Godot 4.x, rendu GL Compatibility)
- [x] Couche de données pures (`scripts/game_data.gd`, autoload `GameData`) : catastrophes, synergies, objectifs (conditions déclaratives), Arbre du Chaos — traduction fidèle des tables de `script.js` de l'original
- [x] Logique d'état/économie (`scripts/game_state.gd`, autoload `GameState`) : achats (catastrophes et nœuds de l'Arbre du Chaos), coûts et production, déblocages, objectifs, calcul du KO, sauvegarde/chargement (`user://`), progression hors-ligne, boucle de jeu auto-pilotée
- [x] HUD fonctionnel (`scripts/main.gd` + `scripts/hud/`) : barre du haut, dock des catastrophes + carte d'achat, modales hors-ligne/reset — construit en code, thème par défaut. **Vérifié en jeu : fonctionne.**
- [ ] Arbre du Chaos (overlay, nœuds, connecteurs, inspecteur, pan/zoom)
- [ ] Rendu du village (équivalent de `render.js`)
- [ ] Passe de fidélité visuelle (bois/parchemin/or, dock en pierre) — nécessitera des allers-retours avec des captures d'écran, comme pour l'Arbre du Chaos sur la version web

Vérifié dans l'éditeur Godot 4.7 : `GameData` expose des données cohérentes à l'exécution, `GameState` a été validé bout en bout (45 vérifications automatiques, toutes au vert), et le HUD fonctionnel (barre du haut, dock, achats, réinitialisation) a été confirmé jouable à l'écran.
