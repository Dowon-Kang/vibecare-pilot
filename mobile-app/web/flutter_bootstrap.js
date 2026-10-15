{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const runner = await engineInitializer.initializeEngine({
        hostElement: document.getElementById('vibecare-app'),
      });
      await runner.runApp();
      document.getElementById('loading')?.remove();
    } catch (error) {
      const loading = document.getElementById('loading');
      if (loading) {
        loading.textContent = '앱을 열지 못했어요. 연결을 확인해 주세요.';
        const retry = document.createElement('button');
        retry.textContent = '다시 열기';
        retry.onclick = () => window.location.reload();
        loading.appendChild(retry);
      }
      console.error('VibeCare initialization failed', error);
    }
  },
});
