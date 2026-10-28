# AnkiConnect's API without the Anki app: serves the collection headless and syncs it with AnkiWeb.
# Not in nixpkgs. Its `anki` dependency is Anki's own collection library (no Qt; the window is the
# separate aqt package), installed from Anki's PyPI wheel rather than nixpkgs' whole app.
{ python3Packages, fetchPypi, autoPatchelfHook, stdenv }:

let
  anki = python3Packages.buildPythonPackage rec {
    pname = "anki";
    version = "26.9.3";
    format = "wheel";
    src = fetchPypi {
      inherit pname version format;
      dist = "cp310";
      python = "cp310";
      abi = "abi3";
      platform = "manylinux_2_35_x86_64";
      hash = "sha256-ez3LbJ4G6Ah+1mu3DzU1blxgaG9R473iX2MoQzByEy8=";
    };
    # the wheel's compiled backend (_rsbridge)
    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib ];
    dependencies = with python3Packages; [
      decorator
      distro
      markdown
      orjson
      protobuf
      requests
      pysocks
      typing-extensions
    ];
    pythonImportsCheck = [ "anki" ];
  };
in
python3Packages.buildPythonApplication rec {
  pname = "anki-connect-server";
  version = "0.5.0";
  format = "wheel";
  src = fetchPypi {
    pname = "anki_connect_server";
    inherit version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-fU8pIou8DtjM4eB50bPBSparJVGE0ckdDklH9T2gxik=";
  };
  dependencies = with python3Packages; [
    anki
    fastapi
    pydantic
    pydantic-settings
    uvicorn
    httpx # installed next to it on Arch too (uv tool install --with httpx)
  ] ++ uvicorn.optional-dependencies.standard;
  # fastmcp is only for the `mcp` subcommand (cli.py imports it there), and nixpkgs marks it broken
  # against mcp 2; `api`, the one the service runs, doesn't touch it. `mcp` fails here.
  pythonRemoveDeps = [ "fastmcp" ];
}
