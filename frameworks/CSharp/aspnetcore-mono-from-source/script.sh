docker build --no-cache --file aspcore-mono-jit-llvm.dockerfile --build-arg MONO_DOCKER_GIT_HASH=${before_change_hash} -t aspcore-mono-jit-llvm-before-change .
docker build --no-cache --file aspcore-mono-jit-llvm.dockerfile --build-arg MONO_DOCKER_GIT_HASH=${after_change_hash} -t aspcore-mono-jit-llvm-after-change .
docker build --no-cache --file aspcore-mono-jit.dockerfile --build-arg MONO_DOCKER_GIT_HASH=${after_change_hash} -t aspcore-mono-jit-after-change .
docker build --no-cache --file aspcore-mono-jit.dockerfile --build-arg MONO_DOCKER_GIT_HASH=${before_change_hash} -t aspcore-mono-jit-before-change .
