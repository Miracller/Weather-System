# Weather-System

This is a repo to show my weather system prototype. 

Key Features:
- Sun and Moon (time of day system)
- Rain and snow
- Rain ripples and droplets for materials
- Simple snow accumulation effect
- Weather Changes and material shifting 
- Cloud system (with a little artifacts)

Tools & Softwares:
- Unity for scene
- UE5 & Blender for preview
- 3ds Max for modeling
- Substance Designer for producing textures
  
---

## Result  

A video of the time of day system. 

https://github.com/user-attachments/assets/3538e36e-6a73-4725-95da-1b3ef61da38b

A video of weather changes and material shifting feature.
As you can see, when it turns from rainy to snowy, the material changes (the white snow accumulated up).

https://github.com/user-attachments/assets/55cecb35-4189-46ee-92b7-e7bd8dff36c5

Some images of the clouds.

![cloud1](https://github.com/user-attachments/assets/c4c1338e-de9f-4703-8c00-8b8162fba6bd)

![cloud2](https://github.com/user-attachments/assets/bb86ee5e-2075-48b5-a7f6-007faf902c25)

---

## Explain of details

I customized new render features in this project to fulfill my requirements.

I used ScriptableObject in Unity to control a variety of conditions in the weather system, such as the precipitation, the temperature, the time, etc.

I write shader codes to control the shifting between snowy shader and rainy shader based on the global temperature.

Because the textures of my assets contains specular and metallic attributes, I modified the Unity PBR shader from using glossy attribute into specular attribute.



---

## Additional Practices
