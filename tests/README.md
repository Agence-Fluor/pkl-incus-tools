# Tests

`test-command.sh` remplace uniquement le binaire `incus` par un simulateur
POSIX. Il utilise le vrai moteur Pkl et le vrai lecteur `pkl-shell`, sans
serveur Incus ni clé. Depuis la racine du projet :

```sh
tests/test-command.sh
```

`consumer/` est un projet Pkl dépendant de la bibliothèque locale et des
versions publiées de `pkl-incus` et `pkl-shell`. Ses
`local.pkl`, `tenant.pkl` et `product.pkl` sont des données ; `main.pkl` est
la commande qui les applique. `smoke-main.pkl` permet un essai réel ciblé sur
le projet `iac-pkl-smoke`, à détruire après l'essai.
