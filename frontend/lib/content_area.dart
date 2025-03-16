              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final description = descriptionController.text.trim();
                  if (name.isNotEmpty) {
                    await playlistService.createPlaylist(name, description: description);
                    if (context.mounted) {
                      Navigator.pop(context);
                      CustomSnackBar.showSuccess(
                        context, 
                        '已创建歌单"$name"'
                      );
                    }
                  } else {
                    CustomSnackBar.showWarning(
                      context, 
                      '歌单名称不能为空'
                    );
                  }
                },
                child: Text('创建歌单'),
              ), 