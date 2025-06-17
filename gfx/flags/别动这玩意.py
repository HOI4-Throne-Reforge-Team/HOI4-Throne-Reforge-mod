import os

def batch_rename(folder_path):
    # 定义替换规则的字典
    replace_rules = {
        "social_liberal": "democratic",
        "authoritarian_democrat": "neutrality",
        "nationalist": "fascism"
    }

    # 遍历文件夹及其所有子文件夹
    for root, dirs, files in os.walk(folder_path):
        for filename in files:
            # 标记文件名是否需要更改
            need_rename = False
            # 用于存储新的文件名
            new_filename = filename

            # 遍历替换规则
            for old_field, new_field in replace_rules.items():
                # 如果文件名中包含旧字段，则进行替换，并标记需要更改
                if old_field in filename:
                    new_filename = new_filename.replace(old_field, new_field)
                    need_rename = True

            # 如果文件名需要更改，则进行重命名操作
            if need_rename:
                old_file_path = os.path.join(root, filename)
                new_file_path = os.path.join(root, new_filename)
                os.rename(old_file_path, new_file_path)
                print(f"文件 {filename} 已重命名为 {new_filename}")
            else:
                print(f"文件 {filename} 不包含指定字段，不做更改")

# 设置文件夹路径
folder_path = "C:/Users/19413/Documents/Paradox Interactive/Hearts of Iron IV/mod/Atropos/gfx/flags"  # 替换为你的实际文件夹路径

# 调用函数执行批量重命名操作
batch_rename(folder_path)