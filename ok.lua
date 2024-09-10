import discord
from discord.ext import commands
import speech_recognition as sr
import openai
import os

# OpenAI API anahtarınızı buraya girin
openai.api_key = 'YOUR_OPENAI_API_KEY'

# Discord botu için gerekli ayarlar
intents = discord.Intents.default()
intents.message_content = True
intents.voice_states = True

bot = commands.Bot(command_prefix='!', intents=intents)
recognizer = sr.Recognizer()

# Kanal ID'sini buraya girin
TARGET_CHANNEL_ID = 123456789012345678  # Botun sesli kanalda olacağı kanal ID'si

@bot.event
async def on_ready():
    print(f'Bot {bot.user.name} olarak giriş yaptı!')
    channel = bot.get_channel(TARGET_CHANNEL_ID)
    if channel:
        await channel.connect()
        print(f'Kanal {channel.name} bağlandı!')
    else:
        print('Hedef kanal bulunamadı!')

@bot.command()
async def leave(ctx):
    if ctx.voice_client:
        await ctx.voice_client.disconnect()
        await ctx.send('Kanalı terk ettim!')
    else:
        await ctx.send('Bot herhangi bir sesli kanalda değil!')

@bot.command()
async def talk(ctx):
    if ctx.voice_client:
        await ctx.send('Bot zaten sesli kanalda.')
    else:
        await ctx.send('Bot herhangi bir sesli kanalda değil!')

async def process_audio(vc):
    with sr.Microphone() as source:
        print("Dinliyorum...")
        audio = recognizer.listen(source)
        try:
            text = recognizer.recognize_google(audio)
            if text.lower().startswith("chatgpt"):
                chat_text = text[8:].strip()
                response = openai.Completion.create(
                    engine="text-davinci-003",
                    prompt=chat_text,
                    max_tokens=50
                )
                chat_response = response.choices[0].text.strip()
                vc.stop()
                # Metni sesli yanıt haline dönüştürmek için
                tts_path = 'response.mp3'
                from gtts import gTTS
                tts = gTTS(chat_response, lang='en')
                tts.save(tts_path)
                vc.play(discord.FFmpegPCMAudio(tts_path))
                os.remove(tts_path)
            else:
                print("Komut 'ChatGPT' ile başlamıyor.")
        except sr.UnknownValueError:
            print("Ses anlaşılamadı.")
        except sr.RequestError as e:
            print(f"API hatası: {e}")

@bot.event
async def on_voice_state_update(member, before, after):
    if after.channel and after.channel.id == TARGET_CHANNEL_ID and not before.channel:
        vc = await after.channel.connect()
        while True:
            await process_audio(vc)
    elif before.channel and before.channel.id == TARGET_CHANNEL_ID and not after.channel:
        if bot.voice_clients:
            await bot.voice_clients[0].disconnect()

# Botunuzu çalıştırmak için gerekli olan kod
bot.run('YOUR_DISCORD_BOT_TOKEN')