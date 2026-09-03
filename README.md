# incrementale-godot

Reconstruction de [Incrementable](https://github.com/juanrobin09-stack/Incrementable) (jeu incremental/idle où le joueur incarne une force de la nature qui déclenche des catastrophes sur un village) sur le moteur **Godot 4.x**.

Reconstruction indépendante, pas un portage automatique : le rendu canvas, le HUD CSS et la logique JS de l'original ne se copient pas tels quels dans Godot — chaque couche est réécrite dans son propre paradigme (nœuds/scènes, `Control`/thèmes, GDScript).

## État actuel

- [x] Squelette du projet (`project.godot`, Godot 4.x, rendu GL Compatibility)
- [x] Couche de données pures (`scripts/game_data.gd`, autoload `GameData`) : catastrophes, synergies, objectifs (conditions déclaratives), Arbre du Chaos — traduction fidèle des tables de `script.js` de l'original
- [ ] Logique d'état/économie (achats, coûts, déblocages, sauvegarde)
- [ ] HUD (scènes `Control`)
- [ ] Rendu du village (équivalent de `render.js`)

Vérifié dans l'éditeur Godot 4.7 : l'autoload `GameData` se charge correctement et expose des données cohérentes à l'exécution (tiers, catastrophes, synergies, objectifs, arbre des améliorations à 21 nœuds) — validé via un smoke-test temporaire, retiré une fois la vérification faite.
