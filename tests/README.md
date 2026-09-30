# Tests

`test-command.sh` remplace uniquement le binaire `incus` par un simulateur
POSIX. Il utilise le vrai moteur Pkl et le vrai lecteur `pkl-shell`, sans
serveur Incus ni clé. Depuis la racine du projet :

```sh
pkl project resolve
pkl project resolve tests/consumer
./flake.pkl develop
tests/test-command.sh
```

Le démarrage du devShell demande Bash 4+, Pkl 0.31.1+ et Nix avec Flakes.
Les deux fichiers `PklProject.deps.json` sont versionnés ; régénérez-les
après modification des dépendances de la bibliothèque.

`consumer/` est un projet Pkl dépendant de la bibliothèque locale et des
versions publiées de `incus-pkl` et `pkl-shell`. Ses
`local.pkl`, `tenant.pkl` et `product.pkl` sont des données ; `main.pkl` est
la commande qui les applique. `smoke-main.pkl` permet un essai réel ciblé sur
le projet `iac-pkl-smoke`, à détruire après l'essai.
