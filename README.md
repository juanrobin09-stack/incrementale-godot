# incrementale-godot

Reconstruction de [Incrementable](https://github.com/juanrobin09-stack/Incrementable) (jeu incremental/idle où le joueur incarne une force de la nature qui déclenche des catastrophes sur un village) sur le moteur **Godot 4.x**.

Reconstruction indépendante, pas un portage automatique : le rendu canvas, le HUD CSS et la logique JS de l'original ne se copient pas tels quels dans Godot — chaque couche est réécrite dans son propre paradigme (nœuds/scènes, `Control`/thèmes, GDScript).

## État actuel

- [x] Squelette du projet (`project.godot`, Godot 4.x, rendu GL Compatibility)
- [x] Couche de données pures (`scripts/game_data.gd`, autoload `GameData`) : catastrophes, synergies, objectifs (conditions déclaratives), Arbre du Chaos — traduction fidèle des tables de `script.js` de l'original
- [x] Logique d'état/économie (`scripts/game_state.gd`, autoload `GameState`) : achats (catastrophes et nœuds de l'Arbre du Chaos), coûts et production, déblocages, objectifs, calcul du KO, sauvegarde/chargement (`user://`), progression hors-ligne, boucle de jeu auto-pilotée
- [ ] HUD (scènes `Control`)
- [ ] Rendu du village (équivalent de `render.js`)

Vérifié dans l'éditeur Godot 4.7 : `GameData` expose des données cohérentes à l'exécution, et `GameState` a été validé bout en bout (achats gratuits/payants, formules de coût et de production avec bonus d'arbre, déblocage par seuil, complétion d'objectifs, calcul exact du KO, aller-retour sauvegarde/chargement, progression hors-ligne, réinitialisation) — 45 vérifications, toutes au vert, via un smoke-test temporaire retiré une fois la vérification faite.
