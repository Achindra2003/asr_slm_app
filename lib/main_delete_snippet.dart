  Future<void> _deleteModel(String modelId) async {
    setState(() {
      _isDeleting = true;
      status = 'Deleting model $modelId...';
    });

    try {
        // Attempt to find and delete model files
        // 1. Unload first if it's current
        if (lm != null && _currentModel == modelId) {
             try {
                await lm!.unload(); 
             } catch (e) {
                print('Unload warning: $e');
             }
        }
        
        // 2. Locate files (heuristic based on common cache paths)
        final appDir = await getApplicationSupportDirectory();
        final cacheDir = await getTemporaryDirectory();
        
        int deletedCount = 0;
        final dirsToCheck = [appDir, cacheDir];
        
        for (var dir in dirsToCheck) {
            if (await dir.exists()) {
                final files = dir.listSync(recursive: true);
                for (var file in files) {
                    if (file is File && file.path.contains(modelId)) {
                        print('Deleting: ${file.path}');
                        await file.delete();
                        deletedCount++;
                    }
                }
            }
        }
        
        setState(() {
           status = 'Deleted $deletedCount files for $modelId';
           _isDeleting = false;
        });

    } catch (e) {
        setState(() {
            status = 'Deletion failed: $e';
            _isDeleting = false;
        });
    }
  }
