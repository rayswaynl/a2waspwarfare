public class EIGHTAT5BMP2ROUND : BaseAmmunition
{
    public EIGHTAT5BMP2ROUND()
    {
        AmmunitionTypes = new List<AmmunitionType>() { AmmunitionType.EIGHTAT5BMP2ROUND };
        amountPerPylon = 1;
        weaponDefinition = (InterfaceWeapon)EnumExtensions.GetInstance(WeaponType.KONKURSLAUNCHERSINGLE.ToString()) as BaseWeapon;
        ammoDisplayName = "Konkurs";
        costPerPylon = 9999999;
    }
}