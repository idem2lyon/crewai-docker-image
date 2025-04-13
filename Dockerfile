FROM python:3.11-slim-bookworm

# --- ARGuments pour versions de CrewAI ---
ARG RELEASE_DATE
ARG CREWAI
ARG TOOLS

# --- Variables d'env basiques ---
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV P=default_crew

# --- Labels et release date ---
LABEL crewai.version=${CREWAI}
LABEL crewai-tools.version=${TOOLS}
LABEL maintainedby="Sammy Ageil"
LABEL release-date=${RELEASE_DATE}

# --- Installation paquets de base, Neovim (build deps), etc. ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    bash-completion \
    ripgrep \
    fzf \
    xclip \
    tree \
    git \
    make \
    cmake \
    build-essential \
    libutf8proc-dev \
    gettext \
    libunibilium-dev \
    gperf \
    luajit \
    luarocks \
    libuv1-dev \
    libmsgpack-dev \
    libtermkey-dev \
    libvterm-dev \
    && rm -rf /var/lib/apt/lists/*

# --- Création user et group ---
RUN groupadd appgroup && \
    useradd -m -s /usr/bin/bash -G appgroup appuser

# --- Copie des scripts de build/entrypoint ---
COPY buildneovim.sh /buildneovim.sh
COPY entrypoint.sh /entrypoint.sh
COPY shell_venv.sh /shell_venv.sh

RUN chmod +x /entrypoint.sh && chmod +x /shell_venv.sh
RUN chmod +x /buildneovim.sh && bash /buildneovim.sh && rm -rf /nvimbuild

# --- Copie et exécution script ajout CrewAI ---
COPY add_crew.sh /add_crew.sh

# --- Nettoyage (suppression paquets de build, si tu veux alléger) ---
RUN apt-get remove --purge --auto-remove -y \
    make \
    build-essential \
    libutf8proc-dev \
    gettext \
    libunibilium-dev \
    gperf \
    luajit \
    luarocks \
    libuv1-dev \
    libmsgpack-dev \
    libtermkey-dev \
    libvterm-dev \
    && apt-get clean

# --- Changement du shell pour bash ---
SHELL ["ln", "-sf","/usr/bin/bash","bin/sh"]

# --- Passage user normal ---
USER appuser

# --- Ajustement shell pour login / interactive ---
SHELL ["/bin/bash", "--login", "-i", "-c"]

# --- Installation NVM + Node ---
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash \
    && nvm install 20

# --- Préparation de l'environnement Python ---
RUN mkdir -p "/home/appuser/.local/bin"
ENV PATH="/home/appuser/.local/bin:$PATH"

WORKDIR /app/
RUN chown -R appuser:appgroup "/app/"

SHELL ["/bin/bash", "-c"]

# --- Installation CrewAI et dépendances Python ---
# 1) Mise à jour pip
# 2) Installation psycopg2-binary (optionnel si tu veux la connexion Postgres)
# 3) Installation CrewAI et CrewAI-tools
RUN python -m pip install --upgrade pip \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && pip install --no-cache-dir psycopg2-binary \
    && pip install --no-cache-dir crewai crewai-tools \
    && echo "source /add_crew.sh" >> ~/.bashrc \
    && echo "alias v='nvim'" >> ~/.bashrc \
    && echo "alias vim='nvim'" >> ~/.bashrc \
    && echo "source /shell_venv.sh" >> ~/.bashrc

# --- Installation LazyVim (d'après le repo) ---
RUN git clone https://github.com/LazyVim/starter /home/appuser/.config/nvim \
    && rm -rf /home/appuser/.config/nvim/.git

COPY options.lua /home/appuser/.config/nvim/lua/config/options.lua
COPY lazy.lua /home/appuser/.config/nvim/lua/config/lazy.lua
COPY treesitter.lua /home/appuser/.config/nvim/lua/plugins/treesitter.lua

# --- Lancement Neovim pour initialiser LazyVim (timeout pour éviter blocage)
RUN timeout 200s nvim || true

# --- Point d'entrée ---
ENTRYPOINT [ "/entrypoint.sh" ]
