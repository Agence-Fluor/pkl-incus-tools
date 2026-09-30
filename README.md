# pkl-incus-tools

[![CI](https://github.com/Agence-Fluor/pkl-incus-tools/actions/workflows/pkl-incus-tools.yml/badge.svg)](https://github.com/Agence-Fluor/pkl-incus-tools/actions/workflows/pkl-incus-tools.yml)

Bibliothèque de description et de déploiement Incus **écrite en Pkl**. Les
types Incus viennent du paquet publié `pkl-incus`. `pkl-shell` est le lecteur
externe nécessaire à Pkl pour lancer le client Incus ; il n'y a pas de moteur
Python ni de CLI de réconciliation distinct.
Pour la toolchain du dépôt, `./flake.pkl develop` utilise le schéma `pkl-nix`
verrouillé par `PklProject.deps.json`. Le shebang lance
[`pkl-nix-tools`](https://github.com/Agence-Fluor/pkl-nix-tools#installer-depuis-pkl),
qui doit être installé dans `PATH`. `pkl eval flake.pkl` affiche le rendu Nix.
Cette passerelle suit le modèle des [lecteurs externes de
Pkl](https://pkl-lang.org/main/current/pkl-cli/index.html#implementing-cli-tools) :
une commande Pkl seule ne peut pas démarrer un programme système.

## Dépendances d'un dépôt consommateur

Après la première publication de ce paquet, déclarer les dépendances dans
`PklProject` :

```pkl
amends "pkl:Project"

dependencies {
  ["tools"] {
    uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-incus-tools/pkl-incus-tools@0.1.3"
  }
  ["shell"] {
    uri = "package://pkg.pkl-lang.org/github.com/Agence-Fluor/pkl-shell/pkl-shell@0.1.1"
  }
}

evaluatorSettings {
  moduleCacheDir = ".pkl-cache"
  externalResourceReaders {
    ["shell"] {
      executable = "sh"
      arguments {
        "-ec"
        "r=.pkl-shell/0.1.1/reader; if [ ! -x \"$r\" ]; then pkl run @shell/install.pkl >/dev/null; chmod +x \"$r\"; fi; exec \"$r\""
      }
    }
  }
}
```

`pkl project resolve` verrouille les versions. Ajouter `.pkl-cache/` et
`.pkl-shell/` au `.gitignore`. Le lecteur est extrait depuis le paquet
`pkl-shell` au premier `--execute`. Pour travailler sur la bibliothèque avant
sa publication, `tests/consumer/PklProject` importe le projet local.

## Organisation

```text
lib/pkl/              Modèles purs : cluster, tenant, environnement, produit, ressources
lib/pkl/Command.pkl   Commande Pkl à étendre dans le dépôt consommateur
lib/engine/Engine.pkl Plan, validation, ordre et appels Incus en Pkl
tests/consumer/       Petit dépôt consommateur servant de fixture
```

Le choix d'interface est **un `main.pkl` exécutable et des `envs/*.pkl` sans
effet de bord**. Ainsi, `pkl eval envs/local.pkl` inspecte uniquement la
configuration, tandis que `pkl run main.pkl` affiche le plan. La modification
du serveur demande explicitement `--execute`.

```pkl
// main.pkl, dans un dépôt qui dépend de cette bibliothèque.
extends "@tools/lib/pkl/Command.pkl"

environment = import("envs/local.pkl")
```

```pkl
// envs/local.pkl
amends "@tools/lib/pkl/Environment.pkl"

remote = "local"
project = "mon-projet"
tenant = import("../tenants/demo.pkl")
products { ["sandbox"] = import("../products/sandbox.pkl") }
```

Commandes depuis le dépôt consommateur :

```sh
pkl eval envs/local.pkl
pkl run main.pkl                             # plan des ressources, sans accès Incus
pkl run main.pkl --scope=full                # plan projet + ressources
pkl run main.pkl --scope=project --execute  # création/MAJ du projet, côté admin
pkl run main.pkl --execute                   # ressources du projet, côté tenant
pkl run main.pkl --action=destroy --execute
pkl run main.pkl --action=destroy --scope=project --execute
```

`--scope=resources` est la valeur par défaut. `full` traite le projet puis
les ressources, en ordre inverse à la destruction. Les ressources d'un produit
doivent être rangées dans l'ordre de leurs dépendances (`dependsOn`). Une
ressource `managed = false` est une dépendance externe déclarée et ne sera
jamais modifiée. Les collisions de noms sont refusées.

## Ce que fait le moteur actuellement

Le moteur sait créer, mettre à jour et supprimer des **projets, réseaux OVN,
profils, instances et volumes custom** sur un remote Incus existant. Il
construit les corps JSON à partir des types `pkl-incus`, ajoute le marqueur
`user.i2s.owner`, interroge Incus et refuse de prendre possession d'un objet
existant sans ce marqueur. Une seconde application met à jour les objets
gérés au lieu de les recréer. La destruction ne cible que les objets marqués
pour cet environnement. Les droits restent ceux du client Incus de l'appelant.
Un changement que l'API Incus ne peut pas modifier sur place est signalé par
Incus ; le moteur ne recrée pas automatiquement l'objet.

Les modèles Pkl couvrent aussi les membres, identités et d'autres ressources
pour préparer la suite. **Formation de cluster, SSH, certificats, ressources
globales et autres types de ressources ne sont pas encore déployés.** Le
moteur rejette les ressources non prises en charge et les champs dont il ne
respecte pas encore la sémantique (`target`, `members`, `parent`, `image`,
`sensitive`). `full` exige donc pour le moment un serveur déjà prêt. Le
réseau d'un projet doit être de type OVN ; son uplink et OVN doivent être
préparés côté Incus. Voir la [documentation des réseaux
Incus](https://linuxcontainers.org/incus/docs/main/explanation/networks/).

## Développement local

```sh
cd pkl-incus-tools
./flake.pkl develop
pkl project resolve
cd tests/consumer && pkl project resolve && pkl run main.pkl --scope=full
cd ../.. && tests/test-command.sh
```

Le flake fournit Pkl, le client Incus et `unzip` pour les tests du paquet.
Le dépôt consommateur doit aussi disposer de `sh` pour démarrer le lecteur
`pkl-shell`. La bibliothèque épingle `pkl-incus` et `pkl-shell` dans son
`PklProject.deps.json` ; elle ne dépend pas des dépôts voisins.

Le test simulé vérifie plan, création, réapplication, destruction et refus
d'une ressource étrangère. `tests/consumer/smoke-main.pkl` cible le projet
local jetable `iac-pkl-smoke` pour un essai réel avec
`--scope=project --execute` ; il faut le détruire ensuite avec
`--action=destroy --scope=project --execute`.

## CI et publication

Le workflow [pkl-incus-tools.yml](.github/workflows/pkl-incus-tools.yml)
contrôle les verrous Pkl, exécute les tests avec un client Incus simulé,
construit une archive ne contenant que `lib/` et l'importe depuis un projet
consommateur isolé. Il publie les quatre fichiers du paquet Pkl lors d'un tag
`pkl-incus-tools@<version>` correspondant à `package.version`.

```sh
./flake.pkl develop \
  --command sh scripts/test-package.sh
./flake.pkl develop \
  --command sh scripts/package-pkl.sh dist/package
```

Les URL de publication pointent vers `Agence-Fluor/pkl-incus-tools`. Pour
publier, pousser le code sur ce dépôt, puis créer le tag correspondant à la
version du `PklProject` :

```sh
tag=$(sh scripts/release-tag.sh)
git tag "$tag"
git push github "$tag"
```

Le workflow ne déploie rien sur un serveur Incus.
